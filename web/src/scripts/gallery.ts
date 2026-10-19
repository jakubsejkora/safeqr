const filters = document.querySelector<HTMLElement>("[data-filters]");
const search = document.querySelector<HTMLInputElement>("#qr-search");
const tools = document.querySelector<HTMLElement>("[data-search-tools]");
const cards = [...document.querySelectorAll<HTMLElement>("[data-qr-card]")];
const count = document.querySelector<HTMLElement>("[data-count]");
const empty = document.querySelector<HTMLElement>("[data-no-results]");
let category = "all";
const normalize = (value: string) =>
  value
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .toLowerCase();
function update() {
  let visible = 0;
  const query = normalize(search?.value ?? "");
  for (const card of cards) {
    card.hidden = !(
      (category === "all" || card.dataset.category === category) &&
      normalize(card.dataset.search ?? "").includes(query)
    );
    if (!card.hidden) visible++;
  }
  if (count)
    count.textContent =
      count.dataset.locale === "en"
        ? `${visible} of ${cards.length} examples`
        : `${visible} z ${cards.length} ukázek`;
  if (empty) empty.hidden = visible > 0;
}
if (filters && tools && search) {
  filters.hidden = false;
  tools.hidden = false;
  for (const button of filters.querySelectorAll<HTMLButtonElement>("button"))
    button.addEventListener("click", () => {
      category = button.dataset.filter ?? "all";
      for (const other of filters.querySelectorAll("button"))
        other.setAttribute("aria-pressed", String(other === button));
      update();
    });
  search.addEventListener("input", update);
}
