defmodule Aesir.ZoneServer.Mmo.Skills.HighWizard.HwMagicpower do
  @moduledoc """
  Mystical Amplification (HW_MAGICPOWER). Self buff raising MATK by 5% per level
  through `:sc_magicpower`.

  Renewal: 35 to 80 SP, 0.7 s cast plus 0.7 s fixed; lasts 180 s and amplifies
  base plus weapon MATK. Pre-renewal: 14 to 50 SP, 0.7 s cast; lasts up to 30 s,
  amplifies final MATK and is spent by the next offensive spell.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 366,
    name: :hw_magicpower,
    status: :sc_magicpower,
    display_name: "Mystical Amplification",
    max_level: 10,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :magic,
    sp_cost: [
      renewal: [35, 40, 45, 50, 55, 60, 65, 70, 75, 80],
      pre_renewal: [14, 18, 22, 26, 30, 34, 38, 42, 46, 50]
    ],
    cast_time: List.duplicate(700, 10),
    fixed_cast_time: [renewal: List.duplicate(700, 10), pre_renewal: []],
    duration: [renewal: List.duplicate(180_000, 10), pre_renewal: List.duplicate(30_000, 10)]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%PlayerState{character_id: id} = caster, :self, level, definition) do
    with :ok <-
           StatusInterpreter.apply_status(:player, id, :sc_magicpower,
             val1: level,
             caster_id: id,
             duration: Enum.at(definition.duration, level - 1)
           ) do
      {:ok, caster}
    end
  end
end
