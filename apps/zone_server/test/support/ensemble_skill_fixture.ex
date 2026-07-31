defmodule Aesir.ZoneServer.TestSupport.EnsembleSkill do
  @moduledoc """
  The only ensemble that exists until the `BD_*` skills ship, used to prove the
  `:ensemble` capability reaches the catalog.

  Unlike a skill defined inside a `.exs` test file, this module lives under
  `test/support`, which `elixirc_paths(:test)` compiles into the `:zone_server`
  application manifest - so `Catalog.discover/0` **does** find it and id 999_998
  is present in `Catalog.all/0` for the whole test run. That is deliberate:
  `Catalog.ensemble?/1` cannot otherwise be exercised. Anything that enumerates
  the catalog (skill trees, mob-cast denylists) must tolerate it.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 999_998,
    name: :ensemble_skill_fixture,
    display_name: "Ensemble Skill Fixture",
    max_level: 1,
    target_type: :self

  use Aesir.ZoneServer.Mmo.Skill.Ensemble

  @impl Aesir.ZoneServer.Mmo.Skill.Active
  def cast(_caster, _target, _level, _definition), do: :ok
end
