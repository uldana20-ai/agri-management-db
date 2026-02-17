-- ============================================================
-- Ауыл шаруашылығын басқару жүйесі (егін + мал) — PostgreSQL
-- ============================================================

CREATE SCHEMA IF NOT EXISTS agri_mgmt;
SET search_path = agri_mgmt;

CREATE TABLE farm (
  farm_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name       TEXT NOT NULL UNIQUE,
  region     TEXT NOT NULL,
  address    TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE employee (
  employee_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  farm_id     BIGINT NOT NULL REFERENCES farm(farm_id) ON DELETE CASCADE,
  full_name   TEXT NOT NULL,
  role_title  TEXT NOT NULL,
  phone       TEXT,
  hired_date  DATE NOT NULL DEFAULT CURRENT_DATE
);
CREATE INDEX idx_employee_farm ON employee(farm_id);


CREATE TABLE field (
  field_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  farm_id    BIGINT NOT NULL REFERENCES farm(farm_id) ON DELETE CASCADE,
  name       TEXT NOT NULL,
  area_ha    NUMERIC(10,2) NOT NULL CHECK (area_ha > 0),
  soil_type  TEXT,
  irrigation BOOLEAN NOT NULL DEFAULT FALSE,
  UNIQUE (farm_id, name)
);
CREATE INDEX idx_field_farm ON field(farm_id);

CREATE TABLE crop (
  crop_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name         TEXT NOT NULL UNIQUE,
  category     TEXT NOT NULL CHECK (category IN ('Дәнді','Көкөніс','Жеміс','Майлы дақыл','Басқа')),
  is_perennial BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE season (
  season_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  year      INT NOT NULL CHECK (year BETWEEN 2000 AND 2100),
  label     TEXT NOT NULL,
  UNIQUE (year, label)
);

CREATE TABLE planting (
  planting_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  field_id        BIGINT NOT NULL REFERENCES field(field_id) ON DELETE RESTRICT,
  crop_id         BIGINT NOT NULL REFERENCES crop(crop_id) ON DELETE RESTRICT,
  season_id       BIGINT NOT NULL REFERENCES season(season_id) ON DELETE RESTRICT,
  sowing_date     DATE NOT NULL,
  planned_area_ha NUMERIC(10,2) NOT NULL CHECK (planned_area_ha > 0),
  planned_yield_t NUMERIC(12,2) CHECK (planned_yield_t >= 0),
  status          TEXT NOT NULL DEFAULT 'Жоспарда'
                  CHECK (status IN ('Жоспарда','Егілді','Өсіп тұр','Жиналды','Бас тартылды')),
  UNIQUE (field_id, crop_id, season_id)
);
CREATE INDEX idx_planting_field  ON planting(field_id);
CREATE INDEX idx_planting_season ON planting(season_id);
CREATE INDEX idx_planting_date   ON planting(sowing_date);

CREATE TABLE crop_operation (
  operation_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  planting_id  BIGINT NOT NULL REFERENCES planting(planting_id) ON DELETE CASCADE,
  op_type      TEXT NOT NULL CHECK (op_type IN ('Тыңайтқыш','Суару','Пестицид','Жырту','Себу','Өңдеу','Басқа')),
  op_date      DATE NOT NULL,
  quantity     NUMERIC(12,3) CHECK (quantity >= 0),
  unit         TEXT,
  cost_kzt     NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (cost_kzt >= 0),
  notes        TEXT
);
CREATE INDEX idx_cropop_planting_date ON crop_operation(planting_id, op_date);

CREATE TABLE harvest (
  harvest_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  planting_id  BIGINT NOT NULL REFERENCES planting(planting_id) ON DELETE CASCADE,
  harvest_date DATE NOT NULL,
  yield_t      NUMERIC(12,2) NOT NULL CHECK (yield_t >= 0),
  moisture_pct NUMERIC(5,2) CHECK (moisture_pct BETWEEN 0 AND 100),
  storage_note TEXT
);
CREATE INDEX idx_harvest_planting_date ON harvest(planting_id, harvest_date);

CREATE TABLE livestock_group (
  group_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  farm_id  BIGINT NOT NULL REFERENCES farm(farm_id) ON DELETE CASCADE,
  species  TEXT NOT NULL CHECK (species IN ('ІҚМ','ҰҚМ','Жылқы','Құс','Шошқа','Басқа')),
  breed    TEXT,
  housing  TEXT
);
CREATE INDEX idx_livestock_group_farm ON livestock_group(farm_id);

-- ✅ COALESCE қолдану үшін UNIQUE INDEX керек
CREATE UNIQUE INDEX uq_livestock_group_natural
ON livestock_group (farm_id, species, COALESCE(breed,''), COALESCE(housing,''));

CREATE TABLE animal (
  animal_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  group_id   BIGINT NOT NULL REFERENCES livestock_group(group_id) ON DELETE RESTRICT,
  tag_code   TEXT NOT NULL UNIQUE,
  sex        CHAR(1) NOT NULL CHECK (sex IN ('M','F')),
  birth_date DATE,
  status     TEXT NOT NULL DEFAULT 'Белсенді' CHECK (status IN ('Белсенді','Сатылды','Өлді','Ауыстырылды'))
);
CREATE INDEX idx_animal_group ON animal(group_id);

CREATE TABLE health_record (
  record_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  animal_id   BIGINT NOT NULL REFERENCES animal(animal_id) ON DELETE CASCADE,
  record_date DATE NOT NULL,
  diagnosis   TEXT,
  treatment   TEXT,
  vet_name    TEXT,
  cost_kzt    NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (cost_kzt >= 0)
);
CREATE INDEX idx_health_animal_date ON health_record(animal_id, record_date);


CREATE TABLE product (
  product_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name         TEXT NOT NULL UNIQUE,
  product_type TEXT NOT NULL CHECK (product_type IN ('Өнім','Жем','Тыңайтқыш','Дәрі','Жанармай','Басқа')),
  unit         TEXT NOT NULL DEFAULT 'кг'
);

CREATE TABLE inventory_lot (
  lot_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  farm_id       BIGINT NOT NULL REFERENCES farm(farm_id) ON DELETE CASCADE,
  product_id    BIGINT NOT NULL REFERENCES product(product_id) ON DELETE RESTRICT,
  lot_date      DATE NOT NULL DEFAULT CURRENT_DATE,
  qty_in        NUMERIC(14,3) NOT NULL CHECK (qty_in >= 0),
  qty_out       NUMERIC(14,3) NOT NULL DEFAULT 0 CHECK (qty_out >= 0),
  unit_cost_kzt NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (unit_cost_kzt >= 0),
  CHECK (qty_out <= qty_in)
);
CREATE INDEX idx_lot_farm_product ON inventory_lot(farm_id, product_id);

CREATE TABLE sale (
  sale_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  farm_id    BIGINT NOT NULL REFERENCES farm(farm_id) ON DELETE CASCADE,
  sale_date  DATE NOT NULL DEFAULT CURRENT_DATE,
  buyer_name TEXT NOT NULL,
  total_kzt  NUMERIC(16,2) NOT NULL DEFAULT 0 CHECK (total_kzt >= 0)
);
CREATE INDEX idx_sale_date ON sale(sale_date);

CREATE TABLE sale_item (
  sale_item_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  sale_id        BIGINT NOT NULL REFERENCES sale(sale_id) ON DELETE CASCADE,
  product_id     BIGINT NOT NULL REFERENCES product(product_id) ON DELETE RESTRICT,
  qty            NUMERIC(14,3) NOT NULL CHECK (qty > 0),
  unit_price_kzt NUMERIC(14,2) NOT NULL CHECK (unit_price_kzt >= 0),
  line_total_kzt NUMERIC(16,2) GENERATED ALWAYS AS (qty * unit_price_kzt) STORED,
  UNIQUE (sale_id, product_id)
);
CREATE INDEX idx_sale_item_sale ON sale_item(sale_id);


CREATE OR REPLACE VIEW v_crop_costs AS
SELECT
  p.planting_id,
  f.name AS field_name,
  c.name AS crop_name,
  s.year,
  COALESCE(SUM(co.cost_kzt),0) AS total_ops_cost_kzt
FROM planting p
JOIN field f ON f.field_id = p.field_id
JOIN crop c ON c.crop_id = p.crop_id
JOIN season s ON s.season_id = p.season_id
LEFT JOIN crop_operation co ON co.planting_id = p.planting_id
GROUP BY p.planting_id, f.name, c.name, s.year;

CREATE OR REPLACE VIEW v_livestock_summary AS
SELECT
  lg.farm_id,
  lg.species,
  COUNT(*) FILTER (WHERE a.status = 'Белсенді') AS active_animals,
  COUNT(*) FILTER (WHERE a.status = 'Сатылды')  AS sold_animals,
  COUNT(*) FILTER (WHERE a.status = 'Өлді')     AS dead_animals
FROM livestock_group lg
JOIN animal a ON a.group_id = lg.group_id
GROUP BY lg.farm_id, lg.species;


INSERT INTO farm(name, region, address) VALUES
('DemoFarm', 'Алматы обл.', 'Қарасай ауд.')
ON CONFLICT DO NOTHING;

INSERT INTO season(year, label) VALUES (2026,'Көктем-Жаз')
ON CONFLICT DO NOTHING;

INSERT INTO crop(name, category, is_perennial) VALUES
('Бидай','Дәнді',FALSE),
('Арпа','Дәнді',FALSE)
ON CONFLICT DO NOTHING;

INSERT INTO field(farm_id, name, area_ha, soil_type, irrigation)
SELECT farm_id, '1-алқап', 120.50, 'Қара топырақ', TRUE
FROM farm WHERE name='DemoFarm'
ON CONFLICT DO NOTHING;

INSERT INTO planting(field_id, crop_id, season_id, sowing_date, planned_area_ha, planned_yield_t, status)
SELECT f.field_id, c.crop_id, s.season_id, DATE '2026-03-20', 100.00, 250.00, 'Егілді'
FROM field f, crop c, season s
WHERE f.name='1-алқап' AND c.name='Бидай' AND s.year=2026 AND s.label='Көктем-Жаз'
ON CONFLICT DO NOTHING;

-- =========================
-- 7) Тексеру сұранысы
-- =========================
-- SELECT table_name FROM information_schema.tables
-- WHERE table_schema='agri_mgmt' ORDER BY table_name;