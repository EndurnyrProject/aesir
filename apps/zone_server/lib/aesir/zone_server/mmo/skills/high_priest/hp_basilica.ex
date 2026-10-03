defmodule Aesir.ZoneServer.Mmo.Skills.HighPriest.HpBasilica do
  @moduledoc """
  Basilica (HP_BASILICA). Two different mechanics behind one skill.

  Renewal: a self buff (`sc_basilica_buff`) for 60 to 180 s: weapon attacks
  deal `5 * level` percent more to Dark and Undead targets and Holy spells gain
  `3 * level` percent. 3 s cast plus 1 s fixed, 1 s after-cast delay, 30 s
  cooldown, 40 to 80 SP, no catalysts.

  Pre-renewal: a 5x5 sanctuary placed on the caster for 20 to 40 s. Every unit
  entering it is shielded from all non-boss damage but cannot attack or cast;
  enemies of the caster are pushed 2 cells out every 300 ms; song statuses are
  not granted on its cells. The caster is rooted, cannot be knocked back by
  non-boss sources, and can only recast Basilica, which ends the field with no
  cast time, SP, or catalysts but with the after-cast delay (creating it has
  none). Casting costs 80 to 120 SP plus a Yellow, Red, and Blue Gemstone and a
  Holy Water, takes 5 to 9 s, and needs a 7x7 area free of walls and of other
  players and monsters, off Land Protector. The field ends on expiry, cancel,
  map change, or the caster's death.

  Player-only in both modes; no monster row casts it.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 362,
    name: :hp_basilica,
    requires: [],
    display_name: "Basilica",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :magic,
    knockback: [renewal: 0, pre_renewal: 2],
    sp_cost: [renewal: [40, 50, 60, 70, 80], pre_renewal: [80, 90, 100, 110, 120]],
    cast_time: [
      renewal: List.duplicate(3_000, 5),
      pre_renewal: [5_000, 6_000, 7_000, 8_000, 9_000]
    ],
    fixed_cast_time: [renewal: List.duplicate(1_000, 5), pre_renewal: []],
    after_cast_delay: [
      renewal: List.duplicate(1_000, 5),
      pre_renewal: [2_000, 3_000, 4_000, 5_000, 6_000]
    ],
    cooldown: [renewal: List.duplicate(30_000, 5), pre_renewal: []],
    duration: [
      renewal: [60_000, 90_000, 120_000, 150_000, 180_000],
      pre_renewal: [20_000, 25_000, 30_000, 35_000, 40_000]
    ],
    item_cost: [
      renewal: [],
      pre_renewal: [
        %{id: 715, amount: 1},
        %{id: 716, amount: 1},
        %{id: 717, amount: 1},
        %{id: 523, amount: 1}
      ]
    ]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(%MobState{}, _target, _level, _definition), do: {:error, :player_only}

  def cast(%PlayerState{} = caster, _target, level, definition) do
    case GameMode.mode() do
      :renewal -> bless_self(caster, level, definition)
      :pre_renewal -> {:error, :not_implemented}
    end
  end

  defp bless_self(%PlayerState{character_id: id} = caster, level, definition) do
    case StatusInterpreter.apply_status(:player, id, :sc_basilica_buff,
           val1: level,
           caster_id: id,
           duration: Enum.at(definition.duration, level - 1)
         ) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
