"""Carga datos demo vía la API (una empresa con productos y una venta).

Uso (con el backend corriendo):
    python scripts/seed.py [BASE_URL]
    # BASE_URL por defecto: http://localhost:8000
"""

import sys

import httpx

BASE = (sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8000") + "/api/v1"

DEMO = {
    "company_name": "Michilín Demo",
    "company_slug": "michilin-demo",
    "email": "demo@michilin.com",
    "password": "password123",
}
PRODUCTS = [
    {"name": "Café 250g", "price_cents": 12000, "initial_stock": 50},
    {"name": "Té verde", "price_cents": 8000, "initial_stock": 30},
    {"name": "Galletas", "price_cents": 4500, "initial_stock": 100},
]


def main() -> None:
    with httpx.Client(base_url=BASE, timeout=20) as c:
        r = c.post("/auth/register", json=DEMO)
        if r.status_code == 409:
            login = {k: DEMO[k] for k in ("company_slug", "email", "password")}
            r = c.post("/auth/login", json=login)
        r.raise_for_status()
        headers = {"Authorization": f"Bearer {r.json()['access_token']}"}

        for p in PRODUCTS:
            resp = c.post("/products", headers=headers, json=p)
            resp.raise_for_status()
            print(f"  producto: {p['name']} (stock {p['initial_stock']})")

        products = c.get("/products", headers=headers).json()
        first = products[0]
        c.post("/sales", headers=headers, json={"product_id": first["id"], "quantity": 2})
        print(f"  venta: 2x {first['name']}")

    print(f"\nDatos demo cargados. Empresa: {DEMO['company_slug']}")
    print(f"Acceso: {DEMO['email']} / {DEMO['password']}")


if __name__ == "__main__":
    main()
