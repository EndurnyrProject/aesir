defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Hermode do
  @moduledoc """
  Wand of Hermode grants complete magic damage immunity and blocks support casts.

  Renewal grants a finite song snapshot; pre-renewal maintains the status while
  an ally stands in the field. Both modes strip the listed effects from allies
  when applied, never from the caster. Self-targeted skills remain usable.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_hermode,
    no_dispel: false,
    properties: [:buff, :prevents_support_skills],
    calc_flags: [:no_magic_damage],
    no_save: true,
    target_types: [:player],
    icon: :hermode

  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @cleared [
    :sc_bleeding,
    :sc_provoke,
    :sc_twohandquicken,
    :sc_concentrate,
    :sc_encpoison,
    :sc_poisonreact,
    :sc_quagmire,
    :sc_angelus,
    :sc_blessing,
    :sc_increaseagi,
    :sc_decreaseagi,
    :sc_slowpoison,
    :sc_impositio,
    :sc_suffragium,
    :sc_aspersio,
    :sc_benedictio,
    :sc_kyrie,
    :sc_magnificat,
    :sc_gloria,
    :sc_aeterna,
    :sc_adrenaline,
    :sc_weaponperfection,
    :sc_overthrust,
    :sc_maximizepower,
    :sc_trickdead,
    :sc_loud,
    :sc_energycoat,
    :sc_aspdpotion1,
    :sc_aspdpotion2,
    :sc_aspdpotion3,
    :sc_speedup1,
    :sc_atkpotion,
    :sc_matkpotion,
    :sc_stripweapon,
    :sc_stripshield,
    :sc_striparmor,
    :sc_striphelm,
    :sc_cp_weapon,
    :sc_cp_shield,
    :sc_cp_armor,
    :sc_cp_helm,
    :sc_autoguard,
    :sc_reflectshield,
    :sc_providence,
    :sc_defender,
    :sc_magicrod,
    :sc_spearquicken,
    :sc_explosionspirits,
    :sc_bladestop,
    :sc_volcano,
    :sc_aurablade,
    :sc_parrying,
    :sc_concentration,
    :sc_tensionrelax,
    :sc_gospel,
    :sc_assumptio,
    :sc_basilica,
    :sc_truesight,
    :sc_windwalk,
    :sc_jointbeat,
    :sc_devotion,
    :sc_sacrifice,
    :sc_steelbody,
    :sc_adrenaline2,
    :sc_stop
  ]

  @impl true
  @spec modifiers(StatusEntry.t(), Definition.context()) :: %{no_magic_damage: 100}
  def modifiers(_instance, _context), do: %{no_magic_damage: 100}

  @impl true
  @spec on_apply(Definition.target(), StatusEntry.t(), Definition.context()) ::
          {:ok, StatusEntry.t()}
  def on_apply({type, id}, instance, _context) do
    if instance.source_id != id do
      ids =
        type
        |> StatusStorage.get_unit_statuses(id)
        |> Enum.filter(&(&1.type in @cleared))
        |> Enum.map(& &1.type)

      Interpreter.remove_statuses(type, id, ids, owner_refresh: :notify)
    end

    {:ok, instance}
  end
end
