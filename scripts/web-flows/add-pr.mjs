// Logs a Back Squat PR (142 kg x 1) through the real UI, as a smoke test that
// the app can write to the local Supabase stack. Coordinates assume the
// default 420x900 viewport; re-screenshot and adjust if the layout changes.
export default async function addPr(page, { base, shot }) {
  const width = page.viewportSize().width;
  const x = width / 2;
  // The form column is 520px wide max with 20px gutters; the stepper's value
  // field sits 90px in from its right edge.
  const valueX = Math.min(width - 20, x + 260) - 90;
  await page.goto(`${base}/#/prs/add`);
  await page.waitForTimeout(3_000);

  await page.mouse.click(x, 96); // exercise autocomplete
  await page.keyboard.type('Back Squat');
  await page.waitForTimeout(1_500);
  await page.mouse.click(x, 143); // the matching option
  await page.waitForTimeout(1_000);

  await page.mouse.click(valueX, 196); // weight stepper's value field
  await page.keyboard.press('Control+a');
  await page.keyboard.type('142');
  await page.keyboard.press('Enter');
  await page.waitForTimeout(800);
  await shot('add-pr-filled');

  await page.mouse.click(x, 518); // Save personal best
  await page.waitForTimeout(3_000);
}
