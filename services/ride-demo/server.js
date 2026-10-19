import { createServer as httpServer } from 'node:http';
import { DatabaseSync } from 'node:sqlite';
import { randomBytes, createHash } from 'node:crypto';
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';

const services = { uberX: 1840, comfort: 2490, uberXL: 2990, green: 1940, black: 3890, pet: 2140 };
const activeStatuses = ['requested', 'accepted', 'arriving', 'in_progress'];
const roomAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const isoNow = () => new Date().toISOString();
const json = value => JSON.stringify(value);
const digest = token => createHash('sha256').update(token).digest('hex');

function fail(status, error) {
  const result = new Error(error);
  result.status = status;
  throw result;
}

function validString(value, max, field, { required = true } = {}) {
  if (typeof value !== 'string' || (required && !value.trim()) || value.length > max) fail(400, `Invalid ${field}`);
  return value.trim();
}

function validPlace(value, field) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) fail(400, `Invalid ${field}`);
  return {
    id: validString(value.id, 100, `${field}.id`),
    name: validString(value.name, 200, `${field}.name`),
    address: validString(value.address, 300, `${field}.address`),
    latitude: coordinate(value.latitude, -90, 90, `${field}.latitude`),
    longitude: coordinate(value.longitude, -180, 180, `${field}.longitude`)
  };
}

function coordinate(value, min, max, field) {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < min || value > max) fail(400, `Invalid ${field}`);
  return value;
}

export function createRideServer({ dataDir = process.env.DATA_DIR ?? '.data', rateLimit = 240, rateWindowMs = 60_000, roomTtlMs = 24 * 60 * 60_000 } = {}) {
  mkdirSync(dataDir, { recursive: true });
  const db = new DatabaseSync(join(dataDir, 'rides.sqlite'));
  db.exec('PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON; PRAGMA busy_timeout=5000;');
  db.exec(`CREATE TABLE IF NOT EXISTS rooms (code TEXT PRIMARY KEY, rider_id TEXT NOT NULL, rider_name TEXT NOT NULL, revision INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS participants (id TEXT PRIMARY KEY, room_code TEXT NOT NULL REFERENCES rooms(code), token_hash TEXT NOT NULL UNIQUE, role TEXT NOT NULL, name TEXT NOT NULL, online INTEGER NOT NULL DEFAULT 0);
    CREATE TABLE IF NOT EXISTS credentials (token_hash TEXT PRIMARY KEY, participant_id TEXT NOT NULL REFERENCES participants(id));
    CREATE TABLE IF NOT EXISTS trips (id TEXT PRIMARY KEY, room_code TEXT NOT NULL REFERENCES rooms(code), request_id TEXT NOT NULL, request_payload TEXT NOT NULL, payload TEXT NOT NULL, created_at TEXT NOT NULL, UNIQUE(room_code, request_id));`);
  const rate = new Map();
  const stmts = {
    room: db.prepare('SELECT * FROM rooms WHERE code = ?'),
    participantByToken: db.prepare('SELECT p.* FROM credentials c JOIN participants p ON p.id = c.participant_id WHERE c.token_hash = ?'),
    participant: db.prepare('SELECT * FROM participants WHERE id = ? AND room_code = ?'),
    participants: db.prepare('SELECT * FROM participants WHERE room_code = ?'),
    trips: db.prepare('SELECT payload FROM trips WHERE room_code = ? ORDER BY created_at DESC, id DESC'),
    trip: db.prepare('SELECT * FROM trips WHERE id = ? AND room_code = ?'),
    request: db.prepare('SELECT * FROM trips WHERE room_code = ? AND request_id = ?'),
    insertRoom: db.prepare('INSERT INTO rooms(code, rider_id, rider_name, created_at) VALUES (?, ?, ?, ?)'),
    insertParticipant: db.prepare('INSERT INTO participants(id, room_code, token_hash, role, name) VALUES (?, ?, ?, ?, ?)'),
    insertTrip: db.prepare('INSERT INTO trips(id, room_code, request_id, request_payload, payload, created_at) VALUES (?, ?, ?, ?, ?, ?)'),
    saveTrip: db.prepare('UPDATE trips SET payload = ? WHERE id = ?'),
    setOnline: db.prepare('UPDATE participants SET online = ? WHERE id = ?'),
    revision: db.prepare('UPDATE rooms SET revision = revision + 1 WHERE code = ?'),
  };

  function state(code) {
    const room = stmts.room.get(code);
    if (!room) fail(404, 'Room not found');
    const people = stmts.participants.all(code);
    return {
      roomCode: code,
      revision: room.revision,
      driverOnline: people.some(person => person.role === 'driver' && person.online === 1),
      onlineDriverIds: people.filter(person => person.role === 'driver' && person.online === 1).map(person => person.id),
      trips: stmts.trips.all(code).map(row => JSON.parse(row.payload))
    };
  }

  function transaction(action) {
    db.exec('BEGIN IMMEDIATE');
    try {
      const result = action();
      db.exec('COMMIT');
      return result;
    } catch (error) {
      db.exec('ROLLBACK');
      throw error;
    }
  }

  function session(code, participant) {
    const token = randomBytes(32).toString('base64url');
    const existing = stmts.participant.get(participant.id, code);
    if (!existing) stmts.insertParticipant.run(participant.id, code, digest(token), participant.role, participant.name);
    db.prepare('INSERT INTO credentials(token_hash, participant_id) VALUES (?, ?)').run(digest(token), participant.id);
    if (participant.role === 'rider') {
      db.prepare('UPDATE rooms SET rider_id = ?, rider_name = ? WHERE code = ?').run(participant.id, participant.name, code);
    }
    return { roomCode: code, participantId: participant.id, token, role: participant.role, name: participant.name, state: state(code) };
  }

  function makeCode() {
    for (let attempt = 0; attempt < 20; attempt++) {
      const code = [...randomBytes(8)].map(byte => roomAlphabet[byte % roomAlphabet.length]).join('');
      if (!stmts.room.get(code)) return code;
    }
    fail(500, 'Could not allocate room');
  }

  async function body(req) {
    const chunks = [];
    let size = 0;
    for await (const chunk of req) {
      size += chunk.length;
      if (size > 32_768) fail(400, 'Request body too large');
      chunks.push(chunk);
    }
    if (!size) return {};
    try {
      const value = JSON.parse(Buffer.concat(chunks).toString('utf8'));
      if (!value || typeof value !== 'object' || Array.isArray(value)) fail(400, 'Expected JSON object');
      return value;
    } catch (error) {
      if (error.status) throw error;
      fail(400, 'Invalid JSON');
    }
  }

  async function handle(req, res) {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    if (req.method === 'OPTIONS') { res.writeHead(204).end(); return; }
    const window = Math.floor(Date.now() / rateWindowMs);
    const key = `${req.socket.remoteAddress}:${window}`;
    const count = (rate.get(key) ?? 0) + 1;
    rate.set(key, count);
    if (count > rateLimit) fail(429, 'Rate limit exceeded');
    for (const entry of rate.keys()) if (!entry.endsWith(`:${window}`)) rate.delete(entry);

    const url = new URL(req.url, 'http://localhost');
    if (url.searchParams.has('token')) fail(400, 'Tokens are not accepted in query strings');
    if (req.method === 'GET' && url.pathname === '/health') { respond(res, 200, { ok: true }); return; }
    if (req.method === 'POST' && url.pathname === '/v1/rooms') {
      const input = await body(req);
      const name = validString(input.name, 80, 'name');
      const roomCode = makeCode();
      const riderId = randomBytes(16).toString('hex');
      const result = transaction(() => {
        stmts.insertRoom.run(roomCode, riderId, name, isoNow());
        return session(roomCode, { id: riderId, role: 'rider', name });
      });
      respond(res, 201, result); return;
    }
    const joinMatch = url.pathname.match(/^\/v1\/rooms\/([A-Z0-9]+)\/join$/);
    if (req.method === 'POST' && joinMatch) {
      const code = joinMatch[1];
      if (code.length < 8 || ![...code].every(char => roomAlphabet.includes(char))) fail(404, 'Room not found');
      const room = stmts.room.get(code);
      if (!room || Date.now() - Date.parse(room.created_at) > roomTtlMs) fail(404, 'Room expired');
      const input = await body(req);
      const role = input.role;
      const name = validString(input.name, 80, 'name');
      if (role !== 'rider' && role !== 'driver') fail(400, 'Invalid role');
      const result = transaction(() => {
        const id = role === 'rider' ? room.rider_id : randomBytes(16).toString('hex');
        const sessionName = role === 'rider' ? stmts.participant.get(id, code).name : name;
        return session(code, { id, role, name: sessionName });
      });
      respond(res, 201, result); return;
    }
    if (!['/v1/state', '/v1/availability', '/v1/trips'].includes(url.pathname) && !/^\/v1\/trips\/[A-Za-z0-9_-]+\/actions$/.test(url.pathname)) fail(404, 'Not found');
    const auth = req.headers.authorization;
    if (typeof auth !== 'string' || !auth.startsWith('Bearer ') || auth.length < 16) fail(401, 'Bearer token required');
    const participant = stmts.participantByToken.get(digest(auth.slice(7)));
    if (!participant) fail(401, 'Invalid bearer token');
    const code = participant.room_code;
    const room = stmts.room.get(code);
    if (!room || Date.now() - Date.parse(room.created_at) > roomTtlMs) fail(404, 'Room expired');
    if (req.method === 'GET' && url.pathname === '/v1/state') { respond(res, 200, state(code)); return; }
    if (req.method === 'POST' && url.pathname === '/v1/availability') {
      const input = await body(req);
      if (participant.role !== 'driver') fail(403, 'Driver role required');
      if (typeof input.online !== 'boolean') fail(400, 'online must be boolean');
      transaction(() => {
        if (!input.online && stmts.trips.all(code).some(row => {
          const trip = JSON.parse(row.payload);
          return trip.driver?.id === participant.id && activeStatuses.includes(trip.status);
        })) fail(409, 'Cannot go offline during an active trip');
        stmts.setOnline.run(input.online ? 1 : 0, participant.id);
        stmts.revision.run(code);
      });
      respond(res, 200, state(code)); return;
    }
    if (req.method === 'POST' && url.pathname === '/v1/trips') {
      const input = await body(req);
      if (participant.role !== 'rider' || participant.id !== room.rider_id) fail(403, 'Room owner rider required');
      const requestId = validString(input.requestId, 36, 'requestId');
      if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(requestId)) fail(400, 'requestId must be a UUID');
      const pickup = validPlace(input.pickup, 'pickup');
      const destination = validPlace(input.destination, 'destination');
      if (!Array.isArray(input.stops) || input.stops.length > 2) fail(400, 'stops must contain at most 2 places');
      const stops = input.stops.map((place, index) => validPlace(place, `stops[${index}]`));
      const routePoints = [pickup, ...stops, destination];
      if (new Set(routePoints.map(point => point.id)).size !== routePoints.length) fail(400, 'Route place IDs must be unique');
      if (new Set(routePoints.map(point => `${point.latitude},${point.longitude}`)).size !== routePoints.length) fail(400, 'Route coordinates must be unique');
      if (!Object.hasOwn(services, input.service)) fail(400, 'Unsupported service');
      const paymentMethod = validString(input.paymentMethod, 80, 'paymentMethod');
      if (/[0-9]{12,}/.test(paymentMethod)) fail(400, 'Payment details are not accepted');
      let scheduledAt = null;
      if (input.scheduledAt !== undefined && input.scheduledAt !== null) {
        if (typeof input.scheduledAt !== 'string' || !/^\d{4}-\d\d-\d\dT/.test(input.scheduledAt) || !Number.isFinite(Date.parse(input.scheduledAt))) fail(400, 'Invalid scheduledAt');
        scheduledAt = new Date(input.scheduledAt).toISOString();
        const delta = Date.parse(scheduledAt) - Date.now();
        if (delta <= 0 || delta > 30 * 24 * 60 * 60_000) fail(400, 'scheduledAt must be within the next 30 days');
      }
      const note = input.note === undefined ? '' : validString(input.note, 500, 'note', { required: false });
      const payload = { pickup, destination, stops, service: input.service, paymentMethod, scheduledAt, note };
      const requestPayload = json(payload);
      const result = transaction(() => {
        const previous = stmts.request.get(code, requestId);
        if (previous) {
          if (previous.request_payload !== requestPayload) fail(409, 'requestId already used with different payload');
          return JSON.parse(previous.payload);
        }
        if (stmts.trips.all(code).some(row => activeStatuses.includes(JSON.parse(row.payload).status))) fail(409, 'Room already has an active trip');
        const createdAt = isoNow();
        const trip = { id: randomBytes(16).toString('hex'), riderId: participant.id, riderName: participant.name, ...payload, status: 'requested', driver: null, fareCents: services[input.service] + 300 * stops.length, createdAt, updatedAt: createdAt, cancellationReason: null, rating: null, tipCents: 0, messages: [] };
        stmts.insertTrip.run(trip.id, code, requestId, requestPayload, json(trip), createdAt);
        stmts.revision.run(code);
        return trip;
      });
      void result;
      respond(res, 201, state(code)); return;
    }
    const actionMatch = url.pathname.match(/^\/v1\/trips\/([A-Za-z0-9_-]+)\/actions$/);
    if (req.method === 'POST' && actionMatch) {
      const tripId = actionMatch[1];
      const input = await body(req);
      const action = validString(input.action, 20, 'action');
      const updated = transaction(() => {
        const row = stmts.trip.get(tripId, code);
        if (!row) fail(404, 'Trip not found');
        const trip = JSON.parse(row.payload);
        const owner = participant.role === 'rider' && participant.id === trip.riderId;
        const assigned = participant.role === 'driver' && participant.id === trip.driver?.id;
        if (action === 'accept') {
          if (participant.role !== 'driver') fail(403, 'Driver role required');
          if (!stmts.participant.get(participant.id, code)?.online) fail(409, 'Driver must be online');
          if (trip.status !== 'requested') fail(409, 'Trip is no longer available');
          trip.status = 'accepted';
          trip.driver = { id: participant.id, name: participant.name, vehicle: 'Toyota Prius', plate: 'DEMO 24', rating: 4.98 };
        } else if (action === 'arrive' || action === 'start' || action === 'complete') {
          if (!assigned) fail(403, 'Assigned driver required');
          const transition = { arrive: ['accepted', 'arriving'], start: ['arriving', 'in_progress'], complete: ['in_progress', 'completed'] }[action];
          if (trip.status !== transition[0]) fail(409, `Cannot ${action} trip from ${trip.status}`);
          trip.status = transition[1];
        } else if (action === 'cancel') {
          if (!owner && !assigned) fail(403, 'Trip owner or assigned driver required');
          if (!['requested', 'accepted', 'arriving'].includes(trip.status)) fail(409, `Cannot cancel trip from ${trip.status}`);
          trip.status = 'cancelled';
          trip.cancellationReason = input.reason === undefined ? null : validString(input.reason, 300, 'reason', { required: false });
        } else if (action === 'rate') {
          if (!owner) fail(403, 'Trip owner rider required');
          if (trip.status !== 'completed') fail(409, 'Only completed trips can be rated');
          if (!Number.isInteger(input.rating) || input.rating < 1 || input.rating > 5) fail(400, 'rating must be an integer from 1 to 5');
          if (!Number.isInteger(input.tipCents) || input.tipCents < 0 || input.tipCents > 10_000) fail(400, 'tipCents must be an integer from 0 to 10000');
          trip.rating = input.rating;
          trip.tipCents = input.tipCents;
        } else if (action === 'message') {
          if (!owner && !assigned) fail(403, 'Trip owner or assigned driver required');
          if (!['accepted', 'arriving', 'in_progress'].includes(trip.status)) fail(409, 'Chat is unavailable for this trip');
          if (trip.messages.length >= 100) fail(409, 'Message history is full');
          const text = validString(input.text, 500, 'text');
          trip.messages.push({ id: randomBytes(16).toString('hex'), senderId: participant.id, senderName: participant.name, text, createdAt: isoNow() });
        } else fail(400, 'Unsupported action');
        trip.updatedAt = isoNow();
        stmts.saveTrip.run(json(trip), trip.id);
        stmts.revision.run(code);
        return trip;
      });
      respond(res, 200, state(code)); return;
    }
    fail(404, 'Not found');
  }

  function respond(res, status, value) {
    res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
    res.end(json(value));
  }

  const server = httpServer((req, res) => {
    handle(req, res).catch(error => {
      if (!res.headersSent) respond(res, error.status ?? 500, { error: error.status ? error.message : 'Internal server error' });
      else res.destroy();
    });
  });
  server.on('close', () => db.close());
  return server;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const server = createRideServer();
  server.listen(Number(process.env.PORT ?? 8787), process.env.HOST ?? '0.0.0.0');
}
