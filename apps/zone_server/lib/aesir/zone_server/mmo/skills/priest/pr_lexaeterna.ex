defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrLexaeterna do
  @moduledoc """
  Lex Aeterna (PR_LEXAETERNA). Marks an enemy so its next qualifying hit deals
  double damage.

  rAthena renewal: `db/re/skill_db.yml:2716-2730`.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 78,
    name: :pr_lexaeterna,
    requires: [],
    status: :sc_aeterna,
    display_name: "Lex Aeterna",
    max_level: 1,
    target_type: :target_enemy,
    damage_type: :no_damage,
    damage_kind: :magic,
    range: 9,
    after_cast_delay: [3_000],
    sp_cost: [10],
    duration: [600_000]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Active

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, {:unit, target_id}, level, definition) do
    caster_id = Caster.for(caster).id(caster)

    with {:ok, %{unit_type: unit_type}} <- Combat.resolve_combatant(target_id),
         :ok <-
           StatusInterpreter.apply_status(unit_type, target_id, :sc_aeterna,
             caster_id: caster_id,
             duration: Enum.at(definition.duration, level - 1)
           ) do
      {:ok, caster}
    end
  end
end
