defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuAcolyte.WeaponMerchant do
  @moduledoc """
  Hidden weapon merchant who collects his guild shipment during the Acolyte training quest.

  ## Behavior

  - On touch, on the third delivery step and carrying a Merchant Box, takes the box and
    advances the quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Jukka (fix up)
    - Lupus
    - SinSloth
    - L0ne_W0lf
    - Capuche
    - Euphy
    - Daegaladh
    - Joseph

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_monk",
        x: 136,
        y: 261,
        dir: 0,
        sprite: 139,
        name: "Weapon Merchant",
        scope: :shared,
        unique_name: "Weapon Merchant#tu",
        trigger: {9, 9}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx) do
    if get_char_var(ctx, :tu_acolyte01, 0) != 20 or count_item(ctx, 1081) == 0 do
      ctx
    else
      ctx
      |> mes("[Weapon Merchant]")
      |> mes("The stuff I requested from the guild is finally here!")
      |> mes("It's pretty tough to keep everything in stock since this is such a remote place.")
      |> next()
      |> mes("[Weapon Merchant]")
      |> mes("Hey, thanks so much!")
      |> mes("Oh, and come here if")
      |> mes("you need anything, okay?")
      |> delitem(1081, 1)
      |> set_char_var(:tu_acolyte01, 21)
      |> close()
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
