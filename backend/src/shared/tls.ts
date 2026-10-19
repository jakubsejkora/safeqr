import { X509Certificate } from "node:crypto";
import { createSecureContext, rootCertificates } from "node:tls";
import intermediates from "../../data/tls-intermediates.json" with {
  type: "json",
};

const roots = rootCertificates.map((pem) => new X509Certificate(pem));
const chain = intermediates.map(({ pem, sha256 }) => {
  const certificate = new X509Certificate(pem);
  if (
    !certificate.ca ||
    certificate.fingerprint256.replaceAll(":", "") !== sha256 ||
    !roots.some(
      (root) =>
        certificate.checkIssued(root) && certificate.verify(root.publicKey),
    )
  )
    throw new Error("Invalid intermediate certificate");
  return pem;
});

// Some public servers omit intermediates. Complete their chain without trusting a new root.
export const webTlsContext = createSecureContext({
  ca: [...rootCertificates, ...chain],
  allowPartialTrustChain: false,
});
