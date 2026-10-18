# Bundled photography

The following eight food photographs were downloaded from Unsplash's image CDN on 2026-10-18 and bundled as JPEGs in `Resources/Assets.xcassets`. Every row is a separate source image covered by the [Unsplash License](https://unsplash.com/license), not this repository's MIT license. The source image identifiers below provide provenance without guessing photographer credits.

| Asset | Unsplash source image and downloaded rendition | Bundled dimensions |
| --- | --- | --- |
| `burger` | [photo-1568901346375-23c9450c58cd](https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=1000&q=85&fm=jpg) | 1000 × 831 |
| `pizza` | [photo-1513104890138-7c749659a591](https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=1000&q=85&fm=jpg) | 1000 × 667 |
| `sushi` | [photo-1579584425555-c3ce17fd4351](https://images.unsplash.com/photo-1579584425555-c3ce17fd4351?auto=format&fit=crop&w=1000&q=85&fm=jpg) | 1000 × 1776 |
| `tacos` | [photo-1599974579688-8dbdd335c77f](https://images.unsplash.com/photo-1599974579688-8dbdd335c77f?auto=format&fit=crop&w=1000&q=85&fm=jpg) | 1000 × 649 |
| `salad` | [photo-1512621776951-a57141f2eefd](https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=1000&q=85&fm=jpg) | 1000 × 667 |
| `chicken` | [photo-1626645738196-c2a7c87a8f58](https://images.unsplash.com/photo-1626645738196-c2a7c87a8f58?auto=format&fit=crop&w=1000&q=85&fm=jpg) | 1000 × 667 |
| `fries` | [photo-1573080496219-bb080dd4f877](https://images.unsplash.com/photo-1573080496219-bb080dd4f877?auto=format&fit=crop&w=1000&q=85&fm=jpg) | 1000 × 1500 |
| `dessert` | [photo-1563805042-7684c019e1cb](https://images.unsplash.com/photo-1563805042-7684c019e1cb?auto=format&fit=crop&w=1000&q=85&fm=jpg) | 1000 × 1779 |

Each image is stored at `<asset>.imageset/<asset>.jpg`, with a universal image entry in its `Contents.json`. The downloaded renditions are 1000 pixels wide and retain their source aspect ratios. Runtime code loads the bundled assets, not these URLs. Images are illustrative category photography, reused across sample dishes; they are not photographs supplied by or attributed to the named restaurants.

## License separation

The [Unsplash terms, section 5](https://unsplash.com/terms) describe the image license as an irrevocable, nonexclusive, worldwide copyright license to download, copy, modify, distribute, perform, and use images for free, including commercially, without permission or required attribution. Attribution is appreciated. The license does not allow compiling images to replicate a similar or competing image service, or selling images without significant modification. Resizing alone is not significant modification.

The photo license does not grant rights to trademarks, recognizable people, or other protected works depicted in an image. Review those rights for any new use. Bundling these photographs in the demo does not transfer ownership, place them under MIT, or imply endorsement by Unsplash, a photographer, a restaurant, or a depicted brand.

Authoritative license: <https://unsplash.com/license>. Related official guidance: [Can I use Unsplash images for personal or commercial projects?](https://help.unsplash.com/en/articles/2612315-can-i-use-unsplash-images-for-personal-or-commercial-projects).
