defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.UpperDrawer370255 do
  @moduledoc """
  Lets the player take Withstander from Allen’s medicine drawer.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "hu_in01",
        x: 370,
        y: 255,
        dir: 3,
        sprite: 139,
        name: "Upper Drawer",
        scope: :shared,
        unique_name: "Upper Drawer#Second",
        trigger: {2, 2}
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Upper Drawer#Second")
  def on_event("OnTouch_", ctx), do: take_medicine(ctx)

  @impl true
  def on_talk(ctx), do: disablenpc(ctx, "Upper Drawer#Second")

  defp take_medicine(ctx) do
    case get_char_var(ctx, :hg_herb, 0) do
      stage when stage in [5, 8] ->
        ctx
        |> mes("^3355FFYou take out one dose of")
        |> mes("Withstander from the drawer.^000000")
        |> set_char_var(:hg_herb, stage + 1)
        |> close()

      _ ->
        ctx
        |> mes("^3355FFThere are several books")
        |> mes("kept inside this drawer.^000000")
        |> close()
    end
  end
end
