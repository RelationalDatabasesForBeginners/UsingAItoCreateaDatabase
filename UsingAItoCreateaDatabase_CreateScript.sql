-- YouTube Channel: https://www.youtube.com/@DatabasesAndSQLForBeginners
-- SQL script used for YouTube Video "Using AI to Create a Database": https://youtu.be/wL5FqRKDBg8

-----------------------------------------------------------------------------------
-- Ask ChatGPT:
-- create a database for ordering of car parts with inventory control
--	use enums for status and transactions
--	use 'money' data type for prices
--	add a trigger that automatically updates inventory when an order item is added
--	or when an item is added to inventory
--	include insert into examples for postgresql
-----------------------------------------------------------------------------------

-- ENUMS
CREATE TYPE order_status AS ENUM ('pending', 'processing', 'shipped', 'cancelled');
CREATE TYPE transaction_type AS ENUM ('add_stock', 'order');

-- PARTS TABLE
CREATE TABLE parts (
    part_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    price MONEY NOT NULL
);

-- INVENTORY TABLE
CREATE TABLE inventory (
    part_id INTEGER PRIMARY KEY REFERENCES parts(part_id),
    quantity INTEGER NOT NULL DEFAULT 0
);

-- ORDERS TABLE
CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    customer_name TEXT NOT NULL,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status order_status DEFAULT 'pending'
);

-- ORDER ITEMS TABLE
CREATE TABLE order_items (
    order_item_id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(order_id) ON DELETE CASCADE,
    part_id INTEGER REFERENCES parts(part_id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    item_price MONEY NOT NULL
);

-- INVENTORY TRANSACTIONS TABLE
CREATE TABLE inventory_transactions (
    transaction_id SERIAL PRIMARY KEY,
    part_id INTEGER REFERENCES parts(part_id),
    transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    transaction_type transaction_type NOT NULL,
    quantity_change INTEGER NOT NULL
);

-- TRIGGER FUNCTION TO UPDATE INVENTORY
CREATE OR REPLACE FUNCTION update_inventory() RETURNS TRIGGER AS $$
BEGIN
    IF TG_TABLE_NAME = 'order_items' THEN
        -- Order placed, reduce quantity in the inventory table
        UPDATE inventory
        SET quantity = quantity - NEW.quantity
        WHERE part_id = NEW.part_id;

		-- Add the order into the inventory_transactions table
        INSERT INTO inventory_transactions(part_id, transaction_type, quantity_change)
        VALUES (NEW.part_id, 'order', -NEW.quantity);

    ELSIF TG_TABLE_NAME = 'inventory_transactions' THEN
        IF NEW.transaction_type = 'add_stock' THEN
            -- New stock added, increase inventory
            INSERT INTO inventory(part_id, quantity)
            VALUES (NEW.part_id, NEW.quantity_change)
            ON CONFLICT (part_id) DO UPDATE
            SET quantity = inventory.quantity + EXCLUDED.quantity;

            -- Log already inserted in this case
        END IF;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- TRIGGERS
CREATE TRIGGER trg_order_items_inventory
AFTER INSERT ON order_items
FOR EACH ROW EXECUTE FUNCTION update_inventory();

CREATE TRIGGER trg_inventory_transactions
AFTER INSERT ON inventory_transactions
FOR EACH ROW EXECUTE FUNCTION update_inventory();


------------------------------------------------------
-- INSERT INTO Examples
------------------------------------------------------
-- Add parts
INSERT INTO parts (name, description, price)
VALUES 
('Brake Pad', 'High-performance brake pad', '59.99'),
('Oil Filter', 'Synthetic oil filter', '14.50'),
('Air Filter', 'Standard air filter', '19.00');

-- Add stock (indirectly via inventory_transactions)
INSERT INTO inventory_transactions (part_id, transaction_type, quantity_change)
VALUES 
(1, 'add_stock', 100),
(2, 'add_stock', 200),
(3, 'add_stock', 150);

-- Create an order
INSERT INTO orders (customer_name)
VALUES ('John Doe');

-- Add order items (this will auto-decrease inventory)
INSERT INTO order_items (order_id, part_id, quantity, item_price)
VALUES 
(1, 1, 2, '59.99'),
(1, 2, 1, '14.50');
