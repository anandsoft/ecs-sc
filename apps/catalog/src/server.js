import express from "express";

const PORT = Number(process.env.PORT || 8080);

const products = [
  {
    id: "h1",
    name: "Harbor Headphones",
    category: "Audio",
    description: "Closed-back wireless headphones with 30-hour battery life.",
    specs: "Bluetooth 5.3 · 30-hour battery · folding case",
  },
  {
    id: "h2",
    name: "Lumen Desk Lamp",
    category: "Office",
    description: "Adjustable LED lamp with warm and cool temperature modes.",
    specs: "2700–5000K · USB-C · dimmable",
  },
  {
    id: "h3",
    name: "Keystone Keyboard",
    category: "Peripherals",
    description: "Hot-swappable mechanical keyboard with quiet tactile switches.",
    specs: "75% layout · hot-swap · quiet tactile",
  },
  {
    id: "h4",
    name: "Canvas Monitor",
    category: "Displays",
    description: "27-inch 4K IPS display with USB-C power delivery.",
    specs: "27in 4K IPS · 65W USB-C PD · 99% sRGB",
  },
  {
    id: "h5",
    name: "Drift Webcam",
    category: "Video",
    description: "1080p webcam with dual mics and an auto-framing sensor.",
    specs: "1080p60 · dual mics · auto-frame",
  },
  {
    id: "h6",
    name: "Anchor USB Hub",
    category: "Accessories",
    description: "Seven-port USB-C hub with HDMI and SD card reader.",
    specs: "7 ports · HDMI 4K · SD / microSD",
  },
];

const palettes = {
  h1: { bg: "#1d2a24", ink: "#f4efe6", accent: "#c4a574" },
  h2: { bg: "#3d2a12", ink: "#f4efe6", accent: "#e0a45a" },
  h3: { bg: "#243018", ink: "#f4efe6", accent: "#8faf6a" },
  h4: { bg: "#1c2733", ink: "#f4efe6", accent: "#7aa0c4" },
  h5: { bg: "#3a1d18", ink: "#f4efe6", accent: "#d27a5a" },
  h6: { bg: "#16332e", ink: "#f4efe6", accent: "#5fb3a3" },
};

function productImage(id) {
  const p = palettes[id] || palettes.h1;
  const glyphs = {
    h1: `<circle cx="80" cy="80" r="28" fill="none" stroke="${p.accent}" stroke-width="10"/><rect x="46" y="52" width="14" height="56" rx="7" fill="${p.ink}"/><rect x="100" y="52" width="14" height="56" rx="7" fill="${p.ink}"/>`,
    h2: `<rect x="74" y="28" width="12" height="54" rx="4" fill="${p.ink}"/><circle cx="80" cy="100" r="22" fill="${p.accent}"/><rect x="54" y="118" width="52" height="8" rx="4" fill="${p.ink}"/>`,
    h3: `<rect x="28" y="58" width="104" height="52" rx="8" fill="${p.ink}"/><rect x="38" y="68" width="84" height="32" rx="4" fill="${p.bg}"/><circle cx="48" cy="84" r="4" fill="${p.accent}"/><circle cx="64" cy="84" r="4" fill="${p.accent}"/><circle cx="80" cy="84" r="4" fill="${p.accent}"/><circle cx="96" cy="84" r="4" fill="${p.accent}"/><circle cx="112" cy="84" r="4" fill="${p.accent}"/>`,
    h4: `<rect x="26" y="36" width="108" height="72" rx="6" fill="${p.ink}"/><rect x="34" y="44" width="92" height="52" fill="${p.bg}"/><rect x="64" y="112" width="32" height="10" fill="${p.accent}"/>`,
    h5: `<circle cx="80" cy="78" r="26" fill="${p.ink}"/><circle cx="80" cy="78" r="14" fill="${p.bg}"/><circle cx="80" cy="78" r="6" fill="${p.accent}"/><rect x="68" y="108" width="24" height="12" rx="3" fill="${p.ink}"/>`,
    h6: `<rect x="36" y="52" width="88" height="56" rx="10" fill="${p.ink}"/><rect x="48" y="66" width="16" height="10" rx="2" fill="${p.bg}"/><rect x="72" y="66" width="16" height="10" rx="2" fill="${p.bg}"/><rect x="96" y="66" width="16" height="10" rx="2" fill="${p.accent}"/>`,
  };
  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 160 160" width="160" height="160">
  <rect width="160" height="160" rx="24" fill="${p.bg}"/>
  ${glyphs[id] || glyphs.h1}
</svg>`;
}

function withImage(product) {
  return { ...product, imageUrl: `/images/${product.id}.svg` };
}

const app = express();

app.get("/health", (_req, res) => {
  res.status(200).type("text/plain").send("ok");
});

app.get("/products", (_req, res) => {
  res.json(products.map(withImage));
});

app.get("/products/:id", (req, res) => {
  const product = products.find((item) => item.id === req.params.id);
  if (!product) {
    res.status(404).json({ error: "Product not found" });
    return;
  }
  res.json(withImage(product));
});

app.get("/images/:file", (req, res) => {
  const id = req.params.file.replace(/\.svg$/i, "");
  if (!products.some((item) => item.id === id)) {
    res.status(404).type("text/plain").send("not found");
    return;
  }
  res.set("Cache-Control", "public, max-age=3600");
  res.type("image/svg+xml").send(productImage(id));
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`catalog listening on ${PORT}`);
});
