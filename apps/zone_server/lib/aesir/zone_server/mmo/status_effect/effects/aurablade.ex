defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Aurablade do
  @moduledoc """
  Aura Blade (SC_AURABLADE).

  Renewal adds `(3 + level) × base level` to physical weapon damage after DEF.
  Pre-renewal adds `20 × level` after DEF, except on Spiral Pierce.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_aurablade,
    no_dispel: false,
    properties: [:buff],
    icon: :aurablade,
    opt3: :aurablade

  alias Aesir.Commons.GameMode

  @impl true
  def modifiers(instance, context) do
    case GameMode.mode() do
      :renewal -> %{post_defense_atk: (3 + instance.val1) * context.target.base_level}
      :pre_renewal -> %{post_defense_atk: 20 * instance.val1, post_defense_atk_excludes: [397]}
    end
  end
end
