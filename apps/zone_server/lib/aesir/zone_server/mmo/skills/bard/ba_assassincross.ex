defmodule Aesir.ZoneServer.Mmo.Skills.Bard.BaAssassincross do
  @moduledoc "Assassin Cross of Sunset (BA_ASSASSINCROSS)."

  import Bitwise

  use Aesir.ZoneServer.Mmo.Skill,
    id: 320,
    name: :ba_assassincross,
    display_name: "Assassin Cross of Sunset",
    max_level: 10,
    target_type: :self,
    damage_type: :no_damage,
    range: 15,
    sp_cost: Enum.to_list(40..85//5),
    duration: List.duplicate(180_000, 10),
    cast_time: List.duplicate(1_000, 10),
    fixed_cast_time: List.duplicate(300, 10),
    after_cast_delay: List.duplicate(300, 10),
    cooldown: List.duplicate(20_000, 10),
    require_weapon: [:musical, :whip]

  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Bard.Cost
  alias Aesir.ZoneServer.Mmo.Skills.Bard.Song
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @behaviour Active

  @mado_option Option.id(:madogear)

  @impl Active
  def dynamic_cost(caster, _target, level, definition),
    do: Cost.resolve(caster, definition, level)

  @impl Active
  def cast(caster, :self, level, _definition) do
    aspd = if level == 10, do: 20, else: 2 * level - 1

    Song.snapshot(caster, 320, level, :sc_assncross, [val2: aspd], eligible?: &eligible?/1)
  end

  defp eligible?(recipient) do
    not StatusStorage.has_status?(:player, recipient.character_id, :sc_quagmire) and
      (recipient.option &&& @mado_option) == 0
  end
end
