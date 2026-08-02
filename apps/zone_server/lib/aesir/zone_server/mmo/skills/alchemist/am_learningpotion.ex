defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AmLearningpotion do
  @moduledoc """
  Learning Potion (AM_LEARNINGPOTION). Increases potion effectiveness and
  pharmacy success rates through consumers that read its learned level.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 227,
    name: :am_learningpotion,
    display_name: "Learning Potion",
    max_level: 10,
    target_type: :passive
end
