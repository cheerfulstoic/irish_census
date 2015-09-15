CREATE CONSTRAINT ON (c:County) ASSERT c.name IS UNIQUE;
CREATE INDEX ON :DED(name);
CREATE INDEX ON :TownlandStreet(name);
CREATE INDEX ON :House(census_id);
CREATE INDEX ON :House(census_year);

CREATE INDEX ON :Resident(id);
CREATE INDEX ON :Resident(census_year);
CREATE INDEX ON :Resident(surname);
CREATE INDEX ON :Resident(forename);
CREATE INDEX ON :Resident(age);
CREATE INDEX ON :Resident(sex);
CREATE INDEX ON :Resident(relation_to_head);
CREATE INDEX ON :Resident(religion);
CREATE INDEX ON :Resident(birthplace);
CREATE INDEX ON :Resident(occupation);
CREATE INDEX ON :Resident(literacy);
CREATE INDEX ON :Resident(irish_language);
CREATE INDEX ON :Resident(marital_status);
CREATE INDEX ON :Resident(specified_illness);
CREATE INDEX ON :Resident(years_married);
CREATE INDEX ON :Resident(children_born);
CREATE INDEX ON :Resident(children_living);


