defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsWeaponperfect do
  @moduledoc """
  Weapon Perfection (BS_WEAPONPERFECT) removes physical weapon size penalties for the caster and nearby party members.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.PartyBuff
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  use Aesir.ZoneServer.Mmo.Skill,
    id: 112,
    name: :bs_weaponperfect,
    display_name: "Weapon Perfection",
    max_level: 5,
    target_type: :self,
    splash_radius: 14,
    sp_cost: [18, 16, 14, 12, 10],
    duration: [10_000, 20_000, 30_000, 40_000, 50_000],
    status: :sc_weaponperfection

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%{character_id: caster_id} = caster, :self, level, definition) do
    params = [
      val1: level,
      caster_id: caster_id,
      duration: PartyBuff.duration_for_caster(caster, Enum.at(definition.duration, level - 1))
    ]

    case PartyBuff.apply(caster, :sc_weaponperfection, params, definition.splash_radius) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
