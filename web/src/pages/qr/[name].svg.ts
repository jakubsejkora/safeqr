import type { APIRoute } from "astro";
import { gallery } from "../../data/gallery";
import { kitCodes } from "../../data/kit";
import { qrImage } from "../../lib/qr";
export function getStaticPaths() {
  const galleryPaths = gallery.flatMap((item) => [
    {
      params: { name: item.id },
      props: {
        payload: item.payload,
        inner: item.arrangement === "nested" ? item.secondPayload : undefined,
      },
    },
    ...(item.secondPayload
      ? [
          {
            params: { name: `${item.id}-second` },
            props: { payload: item.secondPayload, inner: undefined },
          },
        ]
      : []),
  ]);
  return [
    ...galleryPaths,
    ...Object.values(kitCodes).map((item) => ({
      params: { name: item.id },
      props: { payload: item.payload, inner: undefined },
    })),
  ];
}
export const GET: APIRoute = async ({ props }) => {
  const image = await qrImage(props.payload, props.inner);
  return new Response(image.svg, { headers: { "Content-Type": "image/svg+xml" } });
};
