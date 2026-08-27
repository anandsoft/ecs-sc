import { randomUUID } from "node:crypto";
import express from "express";

const PORT = Number(process.env.PORT || 8080);
const CATALOG_BASE_URL = process.env.CATALOG_BASE_URL || "http://catalog:8080";

const prices = [
  { productId: "h1", listPrice: 199, salePrice: 149, onSale: true, stock: 12 },
  { productId: "h2", listPrice: 79, salePrice: 79, onSale: false, stock: 18 },
  { productId: "h3", listPrice: 169, salePrice: 129, onSale: true, stock: 9 },
  { productId: "h4", listPrice: 449, salePrice: 449, onSale: false, stock: 6 },
  { productId: "h5", listPrice: 89, salePrice: 69, onSale: true, stock: 14 },
  { productId: "h6", listPrice: 59, salePrice: 59, onSale: false, stock: 22 },
];

const orders = [];

const app = express();
app.use(express.json());

app.get("/health", (_req, res) => {
  res.status(200).type("text/plain").send("ok");
});

app.get("/prices", (_req, res) => {
  res.json(prices);
});

app.get("/prices/:productId", (req, res) => {
  const price = prices.find((item) => item.productId === req.params.productId);
  if (!price) {
    res.status(404).json({ error: "Price not found" });
    return;
  }
  res.json(price);
});

app.get("/orders", (_req, res) => {
  res.json(orders);
});

app.get("/orders/:id", (req, res) => {
  const order = orders.find((item) => item.id === req.params.id);
  if (!order) {
    res.status(404).json({ error: "Order not found" });
    return;
  }
  res.json(order);
});

app.post("/orders", async (req, res) => {
  const productId = String(req.body?.productId || "");
  const quantity = Number(req.body?.quantity || 0);

  if (!productId || !Number.isInteger(quantity) || quantity < 1) {
    res.status(400).json({ error: "productId and a positive integer quantity are required" });
    return;
  }

  let product;
  try {
    const catalogRes = await fetch(`${CATALOG_BASE_URL}/products/${encodeURIComponent(productId)}`);
    if (catalogRes.status === 404) {
      res.status(404).json({ error: "Product not found in catalog" });
      return;
    }
    if (!catalogRes.ok) {
      res.status(502).json({ error: `Catalog returned ${catalogRes.status}` });
      return;
    }
    product = await catalogRes.json();
  } catch (err) {
    res.status(502).json({ error: `Catalog unreachable: ${err.message}` });
    return;
  }

  const price = prices.find((item) => item.productId === productId);
  if (!price) {
    res.status(404).json({ error: "No price for this product" });
    return;
  }
  if (price.stock < quantity) {
    res.status(409).json({ error: "Not enough stock", stock: price.stock });
    return;
  }

  price.stock -= quantity;
  const unitPrice = price.salePrice;
  const order = {
    id: randomUUID(),
    productId,
    productName: product.name,
    quantity,
    unitPrice,
    total: unitPrice * quantity,
    createdAt: new Date().toISOString(),
    catalogVerified: true,
  };
  orders.unshift(order);
  res.status(201).json({ order, stock: price.stock });
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`sales listening on ${PORT}, catalog at ${CATALOG_BASE_URL}`);
});
