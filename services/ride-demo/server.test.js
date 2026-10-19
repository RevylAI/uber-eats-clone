import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createRideServer } from './server.js';

let dir;
let server;
let base;

before(async () => {
  dir = mkdtempSync(join(tmpdir(), 'ride-demo-'));
  server = createRideServer({ dataDir: dir });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  base = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  await new Promise(resolve => server.close(resolve));
  rmSync(dir, { recursive: true, force: true });
});

async function call(path, { token, method = 'GET', body } = {}) {
  const response = await fetch(`${base}${path}`, {
    method,
    headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}), ...(body ? { 'Content-Type': 'application/json' } : {}) },
    body: body ? JSON.stringify(body) : undefined
  });
  return { status: response.status, data: await response.json() };
}

async function setup(name = 'Rider') {
  const created = await call('/v1/rooms', { method: 'POST', body: { name } });
  const roomCode = created.data.roomCode;
  const join = async (role, name) => call(`/v1/rooms/${roomCode}/join`, { method: 'POST', body: { role, name } });
  return { rider: created.data, roomCode, join };
}

const place = (id, name, latitude, longitude) => ({ id, name, address: `${name} address`, latitude, longitude });
const booking = (requestId = '11111111-1111-4111-8111-111111111111') => ({
  requestId, pickup: place('p', 'Pickup', 37.7, -122.4), destination: place('d', 'Dropoff', 37.8, -122.5),
  stops: [], service: 'uberX', paymentMethod: 'Demo Visa •••• 4242', scheduledAt: null, note: ''
});

test('real clients progress through booking, assignment, chat, completion, and rating', async () => {
  const { rider, roomCode, join } = await setup();
  const driver = (await join('driver', 'Driver')).data;
  assert.equal(rider.token.length > 40, true);
  const created = await call('/v1/trips', { method: 'POST', token: rider.token, body: booking() });
  assert.equal(created.status, 201);
  const tripId = created.data.trips[0].id;
  assert.equal(created.data.trips[0].fareCents, 1840);
  assert.equal(created.data.trips[0].scheduledAt, null);
  assert.equal((await call('/v1/state', { token: driver.token })).data.trips[0].status, 'requested');
  assert.equal((await call('/v1/availability', { method: 'POST', token: driver.token, body: { online: true } })).data.driverOnline, true);
  const accepted = await call(`/v1/trips/${tripId}/actions`, { method: 'POST', token: driver.token, body: { action: 'accept' } });
  assert.equal(accepted.data.trips[0].driver.vehicle, 'Toyota Prius');
  for (const action of ['arrive', 'start', 'complete']) assert.equal((await call(`/v1/trips/${tripId}/actions`, { method: 'POST', token: driver.token, body: { action } })).status, 200);
  const rated = await call(`/v1/trips/${tripId}/actions`, { method: 'POST', token: rider.token, body: { action: 'rate', rating: 5, tipCents: 500 } });
  assert.equal(rated.data.trips[0].rating, 5);
  assert.equal(rated.data.trips[0].tipCents, 500);
  assert.equal(rated.data.roomCode, roomCode);
});

test('room identity recovery, scoped idempotency, and separate room visibility', async () => {
  const { rider, roomCode } = await setup('Owner');
  const recovered = (await call(`/v1/rooms/${roomCode}/join`, { method: 'POST', body: { role: 'rider', name: 'Recovered' } })).data;
  assert.equal(recovered.participantId, rider.participantId);
  assert.equal(recovered.name, rider.name);
  const first = await call('/v1/trips', { method: 'POST', token: rider.token, body: booking() });
  assert.equal(first.data.trips[0].riderName, recovered.name);
  const repeated = await call('/v1/trips', { method: 'POST', token: rider.token, body: booking() });
  assert.equal(first.data.trips[0].id, repeated.data.trips[0].id);
  assert.equal((await call('/v1/trips', { method: 'POST', token: rider.token, body: booking('11111111-1111-4111-8111-111111111112') })).status, 409);
  const other = await setup('Other');
  assert.equal((await call('/v1/state', { token: other.rider.token })).data.trips.length, 0);
  assert.notEqual(other.roomCode, roomCode);
});

test('concurrent drivers cannot both accept, unauthorized actions and cancel/chat rules hold', async () => {
  const { rider, roomCode, join } = await setup();
  const d1 = (await join('driver', 'One')).data;
  const d2 = (await join('driver', 'Two')).data;
  const id = (await call('/v1/trips', { method: 'POST', token: rider.token, body: booking() })).data.trips[0].id;
  await Promise.all([d1, d2].map(driver => call('/v1/availability', { method: 'POST', token: driver.token, body: { online: true } })));
  const results = await Promise.all([d1, d2].map(driver => call(`/v1/trips/${id}/actions`, { method: 'POST', token: driver.token, body: { action: 'accept' } })));
  assert.deepEqual(results.map(result => result.status).sort(), [200, 409]);
  const assigned = results.find(result => result.status === 200).data.trips[0].driver.id;
  const driver = [d1, d2].find(value => value.participantId === assigned);
  const otherDriver = [d1, d2].find(value => value.participantId !== assigned);
  assert.equal((await call(`/v1/trips/${id}/actions`, { method: 'POST', token: rider.token, body: { action: 'message', text: 'On my way' } })).data.trips[0].messages.length, 1);
  assert.equal((await call(`/v1/trips/${id}/actions`, { method: 'POST', token: driver.token, body: { action: 'cancel', reason: 'Changed plans' } })).data.trips[0].status, 'cancelled');
  assert.equal((await call(`/v1/trips/${id}/actions`, { method: 'POST', token: otherDriver.token, body: { action: 'message', text: 'No access' } })).status, 403);
  assert.equal((await call('/v1/state', { token: driver.token })).data.roomCode, roomCode);
});

test('validates auth, role, malformed inputs, query credentials, and transition without mutation', async () => {
  const { rider, roomCode, join } = await setup();
  assert.equal((await call('/v1/state')).status, 401);
  assert.equal((await call('/v1/state?token=secret', { token: rider.token })).status, 400);
  assert.equal((await call('/v1/state', { token: 'invalid' })).status, 401);
  assert.equal((await call('/v1/availability', { method: 'POST', token: rider.token, body: { online: true } })).status, 403);
  assert.equal((await call('/v1/trips', { method: 'POST', token: rider.token, body: { ...booking(), service: 'unsupported' } })).status, 400);
  const id = (await call('/v1/trips', { method: 'POST', token: rider.token, body: booking() })).data.trips[0].id;
  const before = (await call('/v1/state', { token: rider.token })).data.revision;
  assert.equal((await call(`/v1/trips/${id}/actions`, { method: 'POST', token: rider.token, body: { action: 'complete' } })).status, 403);
  assert.equal((await call('/v1/state', { token: rider.token })).data.revision, before);
  assert.equal((await join('bogus', 'Nope')).status, 400);
});

test('omitted schedule defaults to immediate and duplicate route points are rejected', async () => {
  const { rider } = await setup();
  const noSchedule = booking();
  delete noSchedule.scheduledAt;
  const accepted = await call('/v1/trips', { method: 'POST', token: rider.token, body: noSchedule });
  assert.equal(accepted.status, 201);
  assert.equal(accepted.data.trips[0].scheduledAt, null);
  const duplicateId = booking('22222222-2222-4222-8222-222222222222');
  duplicateId.destination = { ...duplicateId.destination, id: duplicateId.pickup.id };
  assert.equal((await call('/v1/trips', { method: 'POST', token: rider.token, body: duplicateId })).status, 400);
  const duplicateCoordinates = booking('33333333-3333-4333-8333-333333333333');
  duplicateCoordinates.destination = { ...duplicateCoordinates.destination, latitude: duplicateCoordinates.pickup.latitude, longitude: duplicateCoordinates.pickup.longitude };
  assert.equal((await call('/v1/trips', { method: 'POST', token: rider.token, body: duplicateCoordinates })).status, 400);
});

test('SQLite WAL persists sessions and state after server restart', async () => {
  const { rider } = await setup('Persistent');
  await call('/v1/trips', { method: 'POST', token: rider.token, body: booking() });
  await new Promise(resolve => server.close(resolve));
  server = createRideServer({ dataDir: dir });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  base = `http://127.0.0.1:${server.address().port}`;
  const restored = await call('/v1/state', { token: rider.token });
  assert.equal(restored.status, 200);
  assert.equal(restored.data.trips[0].riderName, 'Persistent');
});
