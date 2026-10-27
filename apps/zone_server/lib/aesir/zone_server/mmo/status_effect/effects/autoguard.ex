defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Autoguard do
  @moduledoc """
  Guard (SC_AUTOGUARD).

  The persistent shield-block stance toggled by CR_AUTOGUARD, carrying the skill
  level in `val1`. While active, every weapon hit that lands on the holder rolls
  against a per-level block chance in `before_weapon_hit/4`; on a successful roll
  the swing is intercepted (it deals nothing) and a guard sprite plays on the
  holder for nearby viewers.

  Unlike Auto Counter this is not a single-use stance: a successful block leaves
  the status in place, so it keeps guarding every subsequent weapon hit until the
  skill is re-cast to toggle it off. Only weapon-class hits reach this hook -
  basic attacks and weapon skills - so magic and misc damage is never blocked.

  The block chance is fixed when the status starts on its own (5 to 30 percent
  by level, kept in `state.block_chance`); a Devotion copy carries its
  Crusader's chance, or none when inherited at link time. It lasts 300 seconds
  unless re-cast off, is kept across a logout (a restored status is the
  holder's own, as a logout ends every Devotion link and the copies with it,
  so its chance is fixed again from `val1`), and starts and ends its devotees'
  copies (`DevotionMirror`). The shield
  requirement is checked by the skill at cast time, and the
  `:remove_on_unequip_shield` flag drops the stance if the shield is later
  unequipped or displaced without another shield taking its place.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_autoguard,
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:remove_on_hermode],
    duration: 300_000,
    properties: [:buff],
    flags: [:remove_on_unequip_shield],
    icon: :autoguard

  alias Aesir.ZoneServer.Mmo.StatusEffect.DevotionMirror
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Shrink
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.SpecialEffect

  @impl true
  def on_apply(target, instance, context) do
    state =
      if DevotionMirror.copy?(instance),
        do: instance.state,
        else: Map.put(instance.state, :block_chance, block_chance(instance.val1))

    DevotionMirror.started(target, instance, state, context.duration)
    {:ok, %{instance | state: state}}
  end

  @impl true
  def on_expire(target, instance, _context), do: DevotionMirror.ended(target, instance)

  @impl true
  @spec before_weapon_hit(
          {Unit.unit_type(), integer()},
          StatusEntry.t(),
          map(),
          map()
        ) :: :continue | {:intercept, :blocked}
  def before_weapon_hit(_target, _entry, %{ignores_auto_guard: true}, _context), do: :continue

  def before_weapon_hit(
        {unit_type, unit_id},
        %StatusEntry{val1: level} = entry,
        attack_info,
        _context
      ) do
    if :rand.uniform(100) <= Map.get(entry.state, :block_chance, 0) do
      SpecialEffect.play({unit_type, unit_id}, :guard, :area)
      maybe_shrink_stun({unit_type, unit_id}, attack_info, level)
      {:intercept, :blocked}
    else
      :continue
    end
  end

  @spec maybe_shrink_stun({Unit.unit_type(), integer()}, map(), integer()) :: :ok
  defp maybe_shrink_stun(guarder, %{attacker: attacker}, level),
    do: Shrink.maybe_stun_attacker(guarder, attacker, level)

  defp maybe_shrink_stun(_guarder, _attack_info, _level), do: :ok

  @doc """
  The block chance percent of a status started at `level`: 5, 5, 4, 4, 3, 3, 2,
  2, 1, 1 added per level, then 0 twice, then 1 per level beyond.
  """
  @spec block_chance(integer()) :: non_neg_integer()
  def block_chance(level) do
    Enum.reduce(0..(level - 1)//1, 0, fn step, chance ->
      added = 5 - div(step, 2)
      chance + if(added < 0, do: 1, else: added)
    end)
  end
end
