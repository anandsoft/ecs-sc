import { useEffect, useMemo, useState } from "react";

function money(value) {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
  }).format(value);
}

function catalogImage(imageUrl) {
  return `/api/catalog${imageUrl}`;
}

export default function App() {
  const [products, setProducts] = useState([]);
  const [prices, setPrices] = useState([]);
  const [selectedId, setSelectedId] = useState(null);
  const [detail, setDetail] = useState(null);
  const [quote, setQuote] = useState(null);
  const [quantity, setQuantity] = useState(1);
  const [receipts, setReceipts] = useState([]);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [loading, setLoading] = useState(true);
  const [buying, setBuying] = useState(false);

  async function loadShelf() {
    const [catalogRes, salesRes] = await Promise.all([
      fetch("/api/catalog/products"),
      fetch("/api/sales/prices"),
    ]);
    if (!catalogRes.ok) throw new Error(`Catalog returned ${catalogRes.status}`);
    if (!salesRes.ok) throw new Error(`Sales returned ${salesRes.status}`);
    const [catalogJson, salesJson] = await Promise.all([
      catalogRes.json(),
      salesRes.json(),
    ]);
    setProducts(catalogJson);
    setPrices(salesJson);
  }

  useEffect(() => {
    let cancelled = false;
    loadShelf()
      .then(() => {
        if (!cancelled) setError("");
      })
      .catch((err) => {
        if (!cancelled) setError(err.message || "Failed to load store data");
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    if (!selectedId) {
      setDetail(null);
      setQuote(null);
      return;
    }

    let cancelled = false;
    async function loadSelection() {
      setNotice("");
      try {
        const [productRes, priceRes] = await Promise.all([
          fetch(`/api/catalog/products/${selectedId}`),
          fetch(`/api/sales/prices/${selectedId}`),
        ]);
        if (!productRes.ok) throw new Error(`Catalog detail ${productRes.status}`);
        if (!priceRes.ok) throw new Error(`Sales quote ${priceRes.status}`);
        const [product, price] = await Promise.all([productRes.json(), priceRes.json()]);
        if (!cancelled) {
          setDetail(product);
          setQuote(price);
          setQuantity(1);
          setError("");
        }
      } catch (err) {
        if (!cancelled) setError(err.message || "Failed to load product");
      }
    }
    loadSelection();
    return () => {
      cancelled = true;
    };
  }, [selectedId]);

  const listings = useMemo(() => {
    const byId = new Map(prices.map((item) => [item.productId, item]));
    return products.map((product) => ({
      ...product,
      pricing: byId.get(product.id) || null,
    }));
  }, [products, prices]);

  async function buy() {
    if (!selectedId) return;
    setBuying(true);
    setNotice("");
    setError("");
    try {
      const res = await fetch("/api/sales/orders", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ productId: selectedId, quantity }),
      });
      const body = await res.json();
      if (!res.ok) {
        throw new Error(body.error || `Buy failed (${res.status})`);
      }
      setReceipts((current) => [body.order, ...current]);
      setQuote((current) => (current ? { ...current, stock: body.stock } : current));
      setPrices((current) =>
        current.map((item) =>
          item.productId === selectedId ? { ...item, stock: body.stock } : item
        )
      );
      setNotice(`Bought ${body.order.quantity} × ${body.order.productName}`);
    } catch (err) {
      setError(err.message || "Buy failed");
    } finally {
      setBuying(false);
    }
  }

  return (
    <div className="page">
      <header className="hero">
        <p className="eyebrow">Anand's Store</p>
        <h1>Select a product, then buy</h1>
        <p className="lede">
          Images and details come from catalog. Price, stock, and checkout go
          through sales. Sales confirms the product with catalog before it
          accepts an order.{" "}
          <a href="/swagger/">REST API docs (Swagger)</a>
        </p>
      </header>

      {loading && <p className="status">Loading catalog and prices…</p>}
      {error && <p className="status error">{error}</p>}
      {notice && <p className="status ok">{notice}</p>}

      <section className="grid">
        {listings.map((item) => (
          <button
            type="button"
            key={item.id}
            className={`card ${selectedId === item.id ? "selected" : ""}`}
            onClick={() => setSelectedId(item.id)}
          >
            <img
              className="thumb"
              src={catalogImage(item.imageUrl)}
              alt=""
            />
            <div className="card-top">
              <span className="category">{item.category}</span>
              {item.pricing?.onSale && <span className="badge">Sale</span>}
            </div>
            <h2>{item.name}</h2>
            {item.pricing ? (
              <p className="price">
                {item.pricing.onSale && (
                  <span className="list">{money(item.pricing.listPrice)}</span>
                )}
                <strong>{money(item.pricing.salePrice)}</strong>
              </p>
            ) : (
              <p className="price muted">Price unavailable</p>
            )}
          </button>
        ))}
      </section>

      {detail && quote && (
        <section className="checkout">
          <img className="hero-image" src={catalogImage(detail.imageUrl)} alt="" />
          <div>
            <p className="category">{detail.category}</p>
            <h2>{detail.name}</h2>
            <p>{detail.description}</p>
            <p className="muted">{detail.specs}</p>
            <p className="price">
              {quote.onSale && <span className="list">{money(quote.listPrice)}</span>}
              <strong>{money(quote.salePrice)}</strong>
              <span className="muted">{quote.stock} in stock</span>
            </p>
            <div className="buy-row">
              <label>
                Qty
                <input
                  type="number"
                  min="1"
                  max={quote.stock}
                  value={quantity}
                  onChange={(event) => setQuantity(Number(event.target.value))}
                />
              </label>
              <button type="button" className="buy" disabled={buying || quote.stock < 1} onClick={buy}>
                {buying ? "Buying…" : "Buy"}
              </button>
            </div>
          </div>
        </section>
      )}

      {receipts.length > 0 && (
        <section className="orders">
          <h2>Orders this session</h2>
          <ul>
            {receipts.map((order) => (
              <li key={order.id}>
                {order.quantity} × {order.productName} — {money(order.total)}
              </li>
            ))}
          </ul>
        </section>
      )}
    </div>
  );
}
