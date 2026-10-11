# Suggested Power BI DAX measures

Assume tables named `Orders` and `OrderItems`, with relationships configured in the model. Adjust names to your model.

```dax
Total Orders =
DISTINCTCOUNT(Orders[order_id])
```

```dax
Item Sales Value =
SUM(OrderItems[price])
```

```dax
Freight Value =
SUM(OrderItems[freight_value])
```

```dax
Average Order Value =
DIVIDE([Item Sales Value], [Total Orders], 0)
```

```dax
Delivered Orders =
CALCULATE(
    [Total Orders],
    Orders[order_status] = "delivered"
)
```

```dax
Late Delivered Orders =
CALCULATE(
    [Total Orders],
    FILTER(
        Orders,
        Orders[order_status] = "delivered"
            && NOT ISBLANK(Orders[order_delivered_customer_date])
            && NOT ISBLANK(Orders[order_estimated_delivery_date])
            && Orders[order_delivered_customer_date] > Orders[order_estimated_delivery_date]
    )
)
```

```dax
Late Delivery % =
DIVIDE([Late Delivered Orders], [Delivered Orders], 0)
```

```dax
Average Review Score =
AVERAGE(OrderReviews[review_score])
```

**Modeling warning:** One order can have multiple items, payment records, and review rows. Model each table at its correct grain and validate totals to avoid duplicate counting. Item sales value is not profit.
