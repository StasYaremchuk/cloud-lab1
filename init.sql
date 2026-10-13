CREATE TABLE IF NOT EXISTS planes (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    fuel_capacity INTEGER NOT NULL,
    passengers INTEGER NOT NULL
);

INSERT INTO planes (name, fuel_capacity, passengers) VALUES
    ('Boeing 737', 26000, 160),
    ('Airbus A320', 24000, 150),
    ('Boeing 747', 35000, 410),
    ('Embraer 190', 13000, 100);