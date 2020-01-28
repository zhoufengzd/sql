DROP TABLE items;
DROP TABLE orders;

CREATE TABLE items
(
    id SERIAL NOT NULL CONSTRAINT items_pkey PRIMARY KEY,
    upc     INTEGER,
    name    TEXT,
    size    TEXT,
    price   DOUBLE PRECISION,
    taxable BOOLEAN,
    sold_by TEXT
);
CREATE UNIQUE INDEX items_id_uindex ON items (id);

CREATE TABLE orders
(
    id SERIAL NOT NULL CONSTRAINT orders_pkey PRIMARY KEY,
    order_id INTEGER,
    customer_id INTEGER,
    item_id INTEGER CONSTRAINT orders_items_id_fk REFERENCES items,
    name TEXT,
    phone TEXT,
    address TEXT,
    delivered    BOOLEAN,
    quantity     DOUBLE PRECISION
);
CREATE UNIQUE INDEX orders_id_uindex ON orders (id);

INSERT INTO items (id, upc, name, size, price, taxable, sold_by) VALUES (4, 30273, 'Apple', 'per lb', 0.99, false, 'weight');
INSERT INTO items (id, upc, name, size, price, taxable, sold_by) VALUES (1, 4738561, 'Milk', '1 gallon', 2.89, false, 'count');
INSERT INTO items (id, upc, name, size, price, taxable, sold_by) VALUES (2, 8897585, 'Bread', '1 loaf', 3.5, false, 'count');
INSERT INTO items (id, upc, name, size, price, taxable, sold_by) VALUES (5, 3342, 'Banana', '1 each', 0.69, false, 'count');
INSERT INTO items (id, upc, name, size, price, taxable, sold_by) VALUES (6, 908345, 'Cashews', '16 oz', 6.99, false, 'count');
INSERT INTO items (id, upc, name, size, price, taxable, sold_by) VALUES (3, 908347, 'Yogurt', '1 container', 1.25, true, 'count');
INSERT INTO items (id, upc, name, size, price, taxable, sold_by) VALUES (7, 30273, 'Apple', 'per lb', 1.09, false, 'weight');
INSERT INTO items (id, upc, name, size, price, taxable, sold_by) VALUES (8, 3342, 'Banana', 'per lb', 0.56, true, 'weight');

INSERT INTO orders (id, order_id, customer_id, item_id, name, phone, address, delivered, quantity)
VALUES (3, 23, 3456, 1, 'Bob', null, null, false, 2);
INSERT INTO orders (id, order_id, customer_id, item_id, name, phone, address, delivered, quantity)
VALUES (4, 23, 3456, 2, 'Bob', null, null, false, 1);
INSERT INTO orders (id, order_id, customer_id, item_id, name, phone, address, delivered, quantity)
VALUES (5, 23, 3456, 3, 'Bob', null, null, false, 6);
INSERT INTO orders (id, order_id, customer_id, item_id, name, phone, address, delivered, quantity)
VALUES (6, 23, 3456, 5, 'Bob', null, null, false, 3);
INSERT INTO orders (id, order_id, customer_id, item_id, name, phone, address, delivered, quantity)
VALUES (7, 89, 2239, 4, 'Alice', null, null, false, 2);
INSERT INTO orders (id, order_id, customer_id, item_id, name, phone, address, delivered, quantity)
VALUES (8, 89, 2239, 6, 'Alice', null, null, false, 1);
INSERT INTO orders (id, order_id, customer_id, item_id, name, phone, address, delivered, quantity)
VALUES (9, 65, 2239, 1, 'Alice', null, null, true, 1);
INSERT INTO orders (id, order_id, customer_id, item_id, name, phone, address, delivered, quantity)
VALUES (10, 65, 2239, 3, 'Alice', null, null, true, 4);
INSERT INTO orders (id, order_id, customer_id, item_id, name, phone, address, delivered, quantity)
VALUES (11, 65, 2239, 2, 'Alice', null, null, true, 1);

-- ## check data:
select * from items order by upc;
select * from orders order by id, order_id;

-- ## 1. find total payment and average payment per customer
-- select o.customer_id, o.name, sum(i.price * o.quantity) as payment -- exclude tax
--     from orders o
--         join items i on o.item_id = i.id
--     group by o.customer_id, o.name;
-- customer_id | name  | payment
-- -------------+-------+---------
--        2239 | Alice |   20.36
--        3456 | Bob   |   18.85

-- select sum(i.price * o.quantity) as payment -- exclude tax
--     from orders o
--         join items i on o.item_id = i.id

with customer as (
    select count(1) as customer_count
        from (select distinct customer_id from orders) o
),
total_payment as (
    select sum(i.price * o.quantity) as total_payment -- exclude tax
        from orders o
            join items i on o.item_id = i.id
)
select t.total_payment, round((t.total_payment / c.customer_count)::numeric, 2) as average_payment
    from customer c
        cross join total_payment t;

-- ## 2. find and clean up duplicated items
-- assumption: 1. upc is unique. 2. same measure (size), take later price, likely price is update
select *, rank() over (partition by upc, size order by id desc) as rk
    from items
        order by upc, id desc;

-- define remove target
with dup_marked as (
    select *, rank() over (partition by upc, size order by id desc) as rk
        from items
),
dup_matched as (
    select i.id as item_id, d.id as dup_item_id
        from items i
            join dup_marked d on (i.upc = d.upc and i.size = d.size)
        where d.rk > 1 and i.id <> d.id
)
update orders o set item_id = ref.item_id
    from dup_matched ref
        where o.item_id = ref.dup_item_id;

-- select * from dup_matched;
-- item_id | dup_item_id
-- ---------+-------------
--       7 |           4

-- ### random check
-- select * from orders where item_id = 4;
-- id | order_id | customer_id | item_id | name  | phone | address | delivered | quantity
-- ----+----------+-------------+---------+-------+-------+---------+-----------+----------
--  7 |       89 |        2239 |       4 | Alice |       |         | f         |        2

-- select o.item_id as old_item_id, d.item_id as new_item_id
--     from orders o
--         join dup_matched d on o.item_id = d.dup_item_id
-- old_item_id | new_item_id
-- -------------+-------------
--           4 |           7


with dup_marked as (
    select *, rank() over (partition by upc, size order by id desc) as rk
        from items
)
delete from items where id in (select id from dup_marked where rk > 1);

-- ## 3. add location to items
-- item: remove price
--     adding store price table / assume there is already a store table
DROP TABLE stores;
DROP TABLE item_price;
CREATE TABLE stores
(
    id SERIAL NOT NULL CONSTRAINT stores_pkey PRIMARY KEY,
    name TEXT
);


CREATE TABLE item_price
(
    id  SERIAL NOT NULL CONSTRAINT item_price_pkey PRIMARY KEY,
    item_id  INTEGER CONSTRAINT item_price_items_id_fk REFERENCES items,
    store_id INTEGER CONSTRAINT item_price_store_id_fk REFERENCES stores,
    price   DOUBLE PRECISION
);
CREATE UNIQUE INDEX item_price_id_uindex ON item_price (item_id, store_id);

INSERT INTO stores (id, name) VALUES (11, 'store11');
INSERT INTO stores (id, name) VALUES (22, 'store22');

INSERT INTO item_price (id, item_id, store_id, price) VALUES (1, 8, 11, 0.56);
INSERT INTO item_price (id, item_id, store_id, price) VALUES (2, 8, 22, 0.69);

-- ## Part II:
DROP TABLE imported_products;
DROP TABLE category_map;
DROP TABLE product_categorizations;

CREATE TABLE imported_products (
    product_id INTEGER NOT NULL CONSTRAINT imported_products_pkey PRIMARY KEY,
    upc     INTEGER,
    name    TEXT,
    size    TEXT,
    category    TEXT
);

CREATE TABLE category_map (
    id INTEGER NOT NULL CONSTRAINT category_map_pkey PRIMARY KEY,
    category_key  TEXT,
    category_name TEXT,
    parent_category_id INTEGER
);

CREATE TABLE product_categorizations (
    id INTEGER NOT NULL CONSTRAINT product_categorizations_pkey PRIMARY KEY,
    product_id INTEGER NOT NULL,
    category_id INTEGER NOT NULL
);

INSERT INTO imported_products (product_id, upc, name, size, category) VALUES (4, 30273, 'Apple', 'per lb', '2_PRODUCE_FRUITS');
INSERT INTO imported_products (product_id, upc, name, size, category) VALUES (1, 4738561, '2% Milk', '1 gallon', '54_DAIRY_MILK');
INSERT INTO imported_products (product_id, upc, name, size, category) VALUES (2, 8897585, 'Skim Milk', '1 gallon', '55_DAIRY_LOWFATMILK');
INSERT INTO imported_products (product_id, upc, name, size, category) VALUES (5, 3342, 'Banana', '1 each', '2_PRODUCE_FRUITS');
INSERT INTO imported_products (product_id, upc, name, size, category) VALUES (6, 908345, 'Organic Peas', '1 head', '4_PRODUCE_ORG_VEGETABLES');
INSERT INTO imported_products (product_id, upc, name, size, category) VALUES (3, 908347, 'Yogurt', '1 container', '52_DAIRY_YOGURT');
INSERT INTO imported_products (product_id, upc, name, size, category) VALUES (7, 30273, 'Oranges', 'per lb', '3_PRODUCE_VEGETABLES');
INSERT INTO imported_products (product_id, upc, name, size, category) VALUES (8, 3342, 'Potatoes', 'per lb', '3_PRODUCE_VEGETABLES');
INSERT INTO imported_products (product_id, upc, name, size, category) VALUES (9, 30275, 'Organic Apple', 'per lb', '2_PRODUCE_ORG_FRUITS');

INSERT INTO category_map (id, category_key, category_name, parent_category_id) VALUES (600, '1_PRODUCE', 'Produce', null);
INSERT INTO category_map (id, category_key, category_name, parent_category_id) VALUES (604, '2_PRODUCE_FRUITS', 'Produce/Fruits', 600);
INSERT INTO category_map (id, category_key, category_name, parent_category_id) VALUES (608, '3_PRODUCE_VEGETABLES', 'Produce/Vegetables', 600);
INSERT INTO category_map (id, category_key, category_name, parent_category_id) VALUES (606, '4_PRODUCE_ORG_VEGETABLES', 'Produce/Vegetables', 600);
INSERT INTO category_map (id, category_key, category_name, parent_category_id) VALUES (800, '50_DAIRY', 'Dairy', null);
INSERT INTO category_map (id, category_key, category_name, parent_category_id) VALUES (803, '52_DAIRY_YOGURT', 'Dairy/Yogurt', 800);
INSERT INTO category_map (id, category_key, category_name, parent_category_id) VALUES (801, '54_DAIRY_MILK', 'Dairy/Milk', 800);
INSERT INTO category_map (id, category_key, category_name, parent_category_id) VALUES (802, '55_DAIRY_LOWFATMILK', 'Dairy/Milk', 800);

select * from imported_products order by name;
select * from category_map order by id;

-- #II.1
-- By using a view / or materialized view to hide business logic change.
--   This will help reduce the complexity and support easier schema update / data fixes
create view imported_products_view as
    with mapping_fix as (   -- this could be maintained outside as a standalone patching table
        select 30273 as upc, '2_PRODUCE_FRUITS'::text as category
    )
    select dt.product_id, dt.upc, dt.name, dt.size, coalesce (ref.category, dt.category) as category
        from imported_products dt
            left join mapping_fix ref on dt.upc = ref.upc;
--
select * from imported_products_view order by name;

-- #II.2
-- category may have parent / children category
-- a upc maps to a single combination: like Produce -> Produce/Vegetables -> Organic, or Produce -> Produce/Vegetables -> Regular

CREATE TABLE category_map (
    id INTEGER NOT NULL CONSTRAINT category_map_pkey PRIMARY KEY,
    category_key  TEXT,
    category_name TEXT,
    parent_category_id INTEGER,
    grand_parent_category_id INTEGER -- optional
);

INSERT INTO category_map (id, category_key, category_name, parent_category_id, grand_parent_category_id) VALUES (600, '1_PRODUCE', 'Produce', null, null);
INSERT INTO category_map (id, category_key, category_name, parent_category_id, grand_parent_category_id) VALUES (604, '2_PRODUCE_FRUITS', 'Produce/Fruits', 600, null);
INSERT INTO category_map (id, category_key, category_name, parent_category_id, grand_parent_category_id) VALUES (605, '2_PRODUCE_ORG_FRUITS', 'Produce/Org/Fruits', 604, 600);
INSERT INTO category_map (id, category_key, category_name, parent_category_id, grand_parent_category_id) VALUES (608, '3_PRODUCE_VEGETABLES', 'Produce/Vegetables', 600, null);
INSERT INTO category_map (id, category_key, category_name, parent_category_id, grand_parent_category_id) VALUES (606, '4_PRODUCE_ORG_VEGETABLES', 'Produce/Org/Vegetables', 608, 600);
INSERT INTO category_map (id, category_key, category_name, parent_category_id, grand_parent_category_id) VALUES (607, '4_PRODUCE_REG_VEGETABLES', 'Produce/Reg/Vegetables', 608, 600);
INSERT INTO category_map (id, category_key, category_name, parent_category_id, grand_parent_category_id) VALUES (800, '50_DAIRY', 'Dairy', null, null);
INSERT INTO category_map (id, category_key, category_name, parent_category_id, grand_parent_category_id) VALUES (803, '52_DAIRY_YOGURT', 'Dairy/Yogurt', 800, null);
INSERT INTO category_map (id, category_key, category_name, parent_category_id, grand_parent_category_id) VALUES (801, '54_DAIRY_MILK', 'Dairy/Milk', 800, null);
INSERT INTO category_map (id, category_key, category_name, parent_category_id, grand_parent_category_id) VALUES (802, '55_DAIRY_LOWFATMILK', 'Dairy/Milk', 801, 800);

-- To query, two options:
-- 1. display the top / grandparent if available to give broader category
select id, category_key, category_name,
        coalesce(grand_parent_category_id, parent_category_id) as parent_id
    from category_map
        order by id;

-- 2. display the direct parent to find close match
select id, category_key, category_name, parent_category_id as parent_id
    from category_map
        order by id;

-- II.3 products without category mapping, for example, "Organic Apples"
-- a. define new / unmapped category in category map
INSERT INTO category_map (id, category_key, category_name, parent_category_id, grand_parent_category_id) VALUES (-1, '_1_NEW', 'New', null, null);

-- b. for unmapped, insert -1 as new category
INSERT INTO product_categorizations (id, product_id, category_id) VALUES (100, 9, -1);

-- c. this could be listed as new category if customer search for new products,
--    or, could run an update job, to map it to proper categoy once identified
update product_categorizations set category_id = 605
    where product_id = 9;

-- d. could build category mapping table for known product after import
