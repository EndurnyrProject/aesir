defmodule Aesir.ZoneServer.Mmo.Skills.PrLexdivina do
  @moduledoc """
  Lex Divina (PR_LEXDIVINA). Delays a certain Silence application by one second,
  or removes an existing Silence from the target.

  rAthena renewal: `db/re/skill_db.yml:2675-2692` and
  `src/map/skills/acolyte/lexdivina.cpp:12-22`.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 76,
    name: :pr_lexdivina,
    display_name: "Lex Divina",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :no_damage,
    range: 5,
    after_cast_delay: List.duplicate(3_000, 10),
    sp_cost: [20, 20, 20, 20, 20, 18, 16, 14, 12, 10],
    duration: [30_000, 35_000, 40_000, 45_000, 50_000, 60_000, 60_000, 60_000, 60_000, 60_000]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @delay_ms 1_000

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%{character_id: caster_id} = caster, {:unit, target_id}, level, definition) do
    with {:ok, %{unit_type: unit_type}} <- Combat.resolve_combatant(target_id) do
      if StatusStorage.has_status?(unit_type, target_id, :sc_silence) do
        StatusInterpreter.remove_status(unit_type, target_id, :sc_silence)
      else
        duration = Enum.at(definition.duration, level - 1)

        Process.send_after(
          self(),
          {:lex_divina, unit_type, target_id, caster_id, duration},
          @delay_ms
        )
      end

      {:ok, caster}
    end
  end

  @doc false
  @spec apply_silence(:player | :mob, integer(), integer(), pos_integer()) ::
          :ok | {:error, atom()}
  def apply_silence(unit_type, target_id, caster_id, duration) do
    StatusInterpreter.apply_status(unit_type, target_id, :sc_silence,
      caster_id: caster_id,
      duration: duration,
      success_rate: 100
    )
  end
end
