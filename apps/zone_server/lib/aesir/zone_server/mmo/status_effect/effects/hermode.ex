defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Hermode do
  @moduledoc """
  Wand of Hermode grants complete magic damage immunity and blocks support casts.

  Renewal grants a finite song snapshot and clears the Hermode-flagged
  statuses from allies when applied, never from the caster; it is kept across
  a logout, and the restore strips nothing. Pre-renewal maintains the status
  on every unit standing in the field (the field strips the allies' buffs on
  each placement), so a logout ends it with the field. Self-targeted skills
  remain usable.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_hermode,
    no_dispel: false,
    no_clear_buff: false,
    properties: [:buff, :prevents_support_skills],
    calc_flags: [:no_magic_damage],
    no_save: [renewal: false, pre_renewal: true],
    icon: :hermode

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.StatusEffect.ClearBuffs
  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @impl true
  @spec modifiers(StatusEntry.t(), Definition.context()) :: %{no_magic_damage: 100}
  def modifiers(_instance, _context), do: %{no_magic_damage: 100}

  @impl true
  @spec on_apply(Definition.target(), StatusEntry.t(), Definition.context()) ::
          {:ok, StatusEntry.t()}
  def on_apply({type, id}, instance, context) do
    if GameMode.mode() == :renewal and instance.source_id != id and not context.loaded do
      ClearBuffs.clear({type, id}, [:hermode])
    end

    {:ok, instance}
  end
end
