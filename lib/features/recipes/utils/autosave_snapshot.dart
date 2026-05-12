import '../models/recipe.dart';

/// Canonical string fingerprint of the autosaved fields of a recipe.
/// Compared against the previous snapshot to decide whether the
/// autosave timer should actually save (BUG-0033 — browser-throttled
/// Timer.periodic was firing redundant saves after tab refocus).
///
/// Any change in any field flips the snapshot string, so the comparison
/// is just `previous == current`.
String recipeAutosaveSnapshot({
  required String title,
  required String description,
  required String servings,
  required String prepTime,
  required String cookTime,
  required String source,
  required String notes,
  required List<Ingredient> ingredients,
  required List<RecipeInstruction> instructions,
  required List<String> tags,
  required List<String> savedImageUrls,
  required int primaryImageIndex,
  required List<String> videoLinks,
  required List<String> subRecipeIds,
  required bool isWip,
}) {
  return [
    title.trim(),
    description.trim(),
    servings.trim(),
    prepTime.trim(),
    cookTime.trim(),
    source.trim(),
    notes.trim(),
    ingredients
        .map((i) => '${i.name}|${i.quantity ?? ''}|${i.unit ?? ''}')
        .join(';'),
    instructions.map((i) => i.text).join(';'),
    tags.join(','),
    savedImageUrls.join(','),
    primaryImageIndex.toString(),
    videoLinks.join(','),
    subRecipeIds.join(','),
    isWip ? '1' : '0',
  ].join('||');
}
