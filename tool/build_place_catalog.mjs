import { readFile, writeFile } from 'node:fs/promises';

const [inputPath, outputPath, countryCode, countryName] = process.argv.slice(2);

if (!inputPath || !outputPath || !countryCode || !countryName) {
  throw new Error('Usage: node build_place_catalog.mjs <input.tsv> <output.json> <countryCode> <countryName>');
}

const placeClasses = new Set(['PPL', 'PPLA', 'PPLA2', 'PPLA3', 'PPLA4', 'PPLC', 'PPLQ']);
const arabicPattern = /[\u0600-\u06FF]/u;
const rows = (await readFile(inputPath, 'utf8')).split('\n');
const placesById = new Map();

for (const row of rows) {
  const columns = row.trim().split('\t');
  if (columns.length < 19 || columns[6] !== 'P' || !placeClasses.has(columns[7])) continue;
  const [id, defaultName, , alternateNames, latitude, longitude, , , country, , admin1, admin2, admin3, admin4, population, , , timezone] = columns;
  if (country !== countryCode || !latitude || !longitude || !timezone) continue;

  const aliases = [...new Set((alternateNames ?? '').split(',').map((entry) => entry.trim()).filter(Boolean))];
  const arabicName = aliases.find((entry) => arabicPattern.test(entry));
  const populationNumber = Number.parseInt(population, 10) || 0;

  const item = {
    id: `${countryCode.toLowerCase()}-${id}`,
    name: arabicName ?? defaultName,
    fallbackName: defaultName,
    admin1: admin1 || null,
    admin2: admin2 || null,
    admin3: admin3 || null,
    admin4: admin4 || null,
    latitude: Number.parseFloat(latitude),
    longitude: Number.parseFloat(longitude),
    timezone,
    population: populationNumber,
  };

  const existing = placesById.get(item.id);
  if (!existing || item.population > existing.population) placesById.set(item.id, item);
}

const places = [...placesById.values()].sort((left, right) => right.population - left.population || left.name.localeCompare(right.name, 'ar'));
await writeFile(outputPath, JSON.stringify({ version: 1, source: 'GeoNames', country: countryName, countryCode, places }, null, 2));
console.log(`Wrote ${places.length} places to ${outputPath}`);
