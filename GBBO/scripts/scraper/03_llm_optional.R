# 03_llm_optional.R  -- OPTIONAL, and only if you want to catch flavours the
# regex gazetteer misses (foreign or one-off names like "Bethmannchen" -> almond,
# "Amarena" -> cherry). Everything else in the pipeline is pure regex; this is the
# only step that needs an LLM. Minimal, uses ellmer + Claude.
#
# Setup:  install.packages("ellmer");  Sys.setenv(ANTHROPIC_API_KEY = "...")
# Output: ingredients_llm_long.csv  (id, ingredient) -- one row per bake x ingredient

suppressPackageStartupMessages({ library(tidyverse); library(ellmer) })

bakes <- read_csv("challenges_1_14.csv", show_col_types = FALSE) |>
  filter(!is.na(result)) |>
  transmute(id = row_number(), text = str_c(signature, showstopper, sep = " | "))

# ask the model for a plain list of flavour ingredients per bake
schema <- type_object(
  ingredients = type_array(items = type_string(
    "one flavour ingredient, lowercase singular; never a base ingredient (flour, sugar, butter, egg)"))
)

chat <- chat_anthropic(
  model = "claude-sonnet-4-5",
  system_prompt = paste(
    "Extract the distinct flavour ingredients named or clearly implied in each",
    "Great British Bake Off bake. Merge obvious synonyms (frangipane -> almond;",
    "amarena -> cherry). Skip pure theme or pun names with no flavour."
  )
)

res <- parallel_chat_structured(chat, as.list(bakes$text), type = schema, max_active = 5)

llm <- tibble(id = bakes$id, ingredient = map(res, "ingredients")) |>
  unnest(ingredient) |>
  mutate(ingredient = str_squish(str_to_lower(ingredient))) |>
  filter(!ingredient %in% c("flour", "sugar", "butter", "egg", "salt", "water", ""))

write_csv(llm, "ingredients_llm_long.csv")
message("03_llm_optional: ", nrow(llm), " bake-ingredient rows -> ingredients_llm_long.csv")
