defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.EnchantPoison do
  @moduledoc """
  Enchant Poison (SC_ENCPOISON).

  Endows the weapon with the poison element, replacing other weapon endows.
  Confirmed ordinary swings may Poison the target through the existing
  attacker-side damage hook.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_encpoison,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:atk_ele],
    flags: [:remove_on_unequip_weapon],
    end_on_start: [
      :sc_aspersio,
      :sc_fireweapon,
      :sc_waterweapon,
      :sc_windweapon,
      :sc_earthweapon,
      :sc_shadowweapon,
      :sc_ghostweapon,
      :sc_watk_element
    ],
    prevented_by: [:sc_refresh, :sc_inspiration],
    icon: :enchantpoison

  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @impl true
  def modifiers(_instance, _context), do: %{attack_element: :poison}

  @impl true
  def on_dealt_damage(target, instance, hit_info, context),
    do: on_dealt_damage(target, instance, hit_info, context, &roll/0)

  @doc false
  @spec on_dealt_damage(
          Definition.target(),
          StatusEntry.t(),
          map(),
          Definition.context(),
          (-> non_neg_integer())
        ) :: Definition.hook_result()
  def on_dealt_damage({source_type, source_id}, instance, hit_info, _context, roll) do
    chance = 250 + 50 * instance.val1

    if hit_info.damage > 0 and roll.() < chance do
      {target_type, target_id} = hit_info.target

      case StatusInterpreter.apply_status(target_type, target_id, :sc_poison,
             caster_id: source_id,
             source_type: source_type,
             duration: 10_000 * instance.val1
           ) do
        :ok ->
          {:ok, instance}

        {:error, reason}
        when reason in [:immune, :boss_immune, :prevented, :conflict, :resisted, :target_dead] ->
          {:ok, instance}

        {:error, reason} ->
          raise "SC_POISON application failed: #{inspect(reason)}"
      end
    else
      {:ok, instance}
    end
  end

  defp roll, do: :rand.uniform(10_000) - 1
end
