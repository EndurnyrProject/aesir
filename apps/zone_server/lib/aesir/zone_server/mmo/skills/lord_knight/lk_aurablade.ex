defmodule Aesir.ZoneServer.Mmo.Skills.LordKnight.LkAurablade do
  @moduledoc """
  Aura Blade (LK_AURABLADE) grants a self-buff with a listed weapon equipped,
  including bows and knuckles but not bare fists.

  Renewal adds level-scaled post-defense ATK; pre-renewal grants a flat bonus
  except for Spiral Pierce. Both modes last 40–120 seconds by skill level.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 355,
    name: :lk_aurablade,
    display_name: "Aura Blade",
    max_level: 5,
    target_type: :self,
    status: :sc_aurablade,
    require_weapon: [
      :dagger,
      :one_handed_sword,
      :two_handed_sword,
      :one_handed_spear,
      :two_handed_spear,
      :one_handed_axe,
      :two_handed_axe,
      :mace,
      :two_handed_mace,
      :staff,
      :bow,
      :knuckle,
      :musical,
      :whip,
      :book,
      :katar,
      :revolver,
      :rifle,
      :gatling,
      :shotgun,
      :grenade,
      :huuma
    ],
    sp_cost: [18, 26, 34, 42, 50],
    duration: [40_000, 60_000, 80_000, 100_000, 120_000]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Active

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, :self, level, definition), do: apply_buff(caster, level, definition)
  def cast(caster, {:unit, _id}, level, definition), do: apply_buff(caster, level, definition)

  defp apply_buff(caster, level, definition) do
    type = caster.__struct__.get_unit_type(caster)
    id = caster.__struct__.get_unit_id(caster)

    StatusInterpreter.apply_status(type, id, :sc_aurablade,
      val1: level,
      duration: Enum.at(definition.duration, level - 1),
      caster_id: id
    )

    {:ok, caster}
  end
end
