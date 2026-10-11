from pathlib import Path
import pandas as pd

DATA_DIR = Path("data/raw")
ORDERS_FILE = DATA_DIR / "olist_orders_dataset.csv"
ITEMS_FILE = DATA_DIR / "olist_order_items_dataset.csv"
CUSTOMERS_FILE = DATA_DIR / "olist_customers_dataset.csv"

def load_csv(path: Path) -> pd.DataFrame:
    if not path.exists():
        raise FileNotFoundError(
            f"Could not find {path}. Download the Olist dataset and place CSVs in data/raw/."
        )
    return pd.read_csv(path)

def main():
    orders = load_csv(ORDERS_FILE)
    items = load_csv(ITEMS_FILE)
    customers = load_csv(CUSTOMERS_FILE)

    print("\\n--- SHAPES ---")
    print("orders:", orders.shape)
    print("items:", items.shape)
    print("customers:", customers.shape)

    print("\\n--- DATA QUALITY: ORDERS ---")
    print("Duplicate order_id rows:", orders["order_id"].duplicated().sum())
    print("Missing values by column:")
    print(orders.isna().sum().sort_values(ascending=False).head(10))

    date_cols = [
        "order_purchase_timestamp",
        "order_approved_at",
        "order_delivered_carrier_date",
        "order_delivered_customer_date",
        "order_estimated_delivery_date",
    ]
    for col in date_cols:
        if col in orders.columns:
            orders[col] = pd.to_datetime(orders[col], errors="coerce")

    delivered = orders.loc[orders["order_status"].eq("delivered")].copy()
    delivered["days_to_delivery"] = (
        delivered["order_delivered_customer_date"] -
        delivered["order_purchase_timestamp"]
    ).dt.total_seconds() / 86400

    delivered["delivery_status"] = "Unknown"
    valid_dates = (
        delivered["order_delivered_customer_date"].notna()
        & delivered["order_estimated_delivery_date"].notna()
    )
    delivered.loc[valid_dates, "delivery_status"] = (
        delivered.loc[valid_dates, "order_delivered_customer_date"]
        <= delivered.loc[valid_dates, "order_estimated_delivery_date"]
    ).map({True: "On time or early", False: "Late"})

    print("\\n--- DELIVERY SUMMARY ---")
    print(delivered["delivery_status"].value_counts(dropna=False))
    print("Average days to delivery:", round(delivered["days_to_delivery"].mean(), 2))

    # Aggregate item values by order before joining to order-level data.
    item_by_order = (
        items.groupby("order_id", as_index=False)
        .agg(
            item_sales_value=("price", "sum"),
            freight_value=("freight_value", "sum"),
            item_count=("order_item_id", "count"),
        )
    )
    analysis = delivered.merge(item_by_order, on="order_id", how="left", validate="one_to_one")
    print("\\n--- MONTHLY SUMMARY ---")
    analysis["order_month"] = analysis["order_purchase_timestamp"].dt.to_period("M").astype(str)
    monthly = (
        analysis.groupby("order_month", dropna=False)
        .agg(
            orders=("order_id", "nunique"),
            item_sales_value=("item_sales_value", "sum"),
            freight_value=("freight_value", "sum"),
        )
        .reset_index()
        .sort_values("order_month")
    )
    print(monthly.tail(12).to_string(index=False))

    # Customer table has one row per order/customer_id in the source; use unique customer ID
    # only for order-to-customer joins. For repeat purchase analysis use customer_unique_id.
    customer_map = customers[["customer_id", "customer_unique_id"]].drop_duplicates()
    customer_orders = delivered[["order_id", "customer_id"]].merge(
        customer_map, on="customer_id", how="left", validate="many_to_one"
    )
    repeat = customer_orders.groupby("customer_unique_id")["order_id"].nunique()
    print("\\nUnique customers:", repeat.size)
    print("Repeat customers:", int((repeat > 1).sum()))
    print("Repeat customer %:", round((repeat > 1).mean() * 100, 2))

    output_dir = Path("reports")
    output_dir.mkdir(exist_ok=True)
    monthly.to_csv(output_dir / "monthly_summary.csv", index=False)
    print(f"\\nSaved {output_dir / 'monthly_summary.csv'}")

if __name__ == "__main__":
    main()
