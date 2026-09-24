defmodule Aesir.ZoneServer.Content.Npc.PreRe.Guides.GuidesPayon.Guide do
  @moduledoc """
  Payon guide who directs visitors to the city's facilities.

  ## Behavior

  - Describes destinations and optionally marks them on the mini-map.
  - Removes marks on request and explains mini-map controls.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Darkchild
    - Lupus
    - MasterOfMuppets
    - erKURITA
    - Silent

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "payon",
        x: 162,
        y: 67,
        dir: 4,
        sprite: 708,
        name: "Guide",
        scope: :pre_renewal,
        unique_name: "Guide#pay"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @locations [
    {"^FF0000Archer Guild^000000",
     [
       "The Archer Guild handles",
       "Job Changes to the Archer",
       "Class. You'll need to enter",
       "the Archer Village which is",
       "to the northeast of Payon."
     ], {227, 328, 2, 0xFF0000}},
    {"Weapon Shop",
     ["The Weapon Shop", "can be found in the", "northwest corner of", "the city of Payon."],
     {139, 159, 3, 0xFF00FF}},
    {"Tool Shop", ["The Tool Shop", "is located near", "the northwest", "corner of Payon."],
     {144, 85, 4, 0xFF00FF}},
    {"Pub",
     [
       "The Pub can be",
       "found in the northeast",
       "part of Payon. It's the",
       "best place to relax after",
       "a long day of hunting."
     ], {220, 117, 5, 0xFF00FF}},
    {"Central Palace",
     ["The Central Palace", "is located to the north", "within the city of Payon."],
     {155, 245, 6, 0x00FF00}},
    {"The Empress", ["The Empress", "can be found to the", "northwest in Payon."],
     {107, 324, 7, 0x00FF00}},
    {"Palace Annex", ["The Palace Annex", "can be found in the", "western part of Payon."],
     {130, 204, 8, 0x00FF00}},
    {"Royal Kitchen", ["The Royal Kitchen", "is located near the", "northern end of Payon."],
     {154, 325, 9, 0x00FF00}},
    {"Forge", ["The Forge is", "situated near", "the center of Payon."], {126, 169, 10, 0xFFFF00}}
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> cutin("pay_soldier", 2)
    |> mes("[Payon Guide]")
    |> mes("Welcome to the")
    |> mes("mountain city of Payon.")
    |> mes("If you're unfamiliar with this")
    |> mes("area, I can help you find what")
    |> mes("you're looking for around here.")
    |> main_menu(false, false)
    |> cutin("", 255)
  end

  defp main_menu(ctx, marking?, guide_opened?) do
    {ctx, choice} =
      ctx |> next() |> select(["City Guide", "Remove Marks from Mini-Map", "Notice.", "Cancel"])

    case choice do
      1 ->
        {ctx, marking?} =
          ctx
          |> mes("[Payon Guide]")
          |> mes("Please select")
          |> mes("a location from")
          |> mes("the following menu.")
          |> offer_marks(marking?)

        ctx |> city_guide(marking?, guide_opened?) |> main_menu(marking?, true)

      2 ->
        ctx |> clear_marks() |> main_menu(false, guide_opened?)

      3 ->
        ctx |> notice() |> main_menu(marking?, guide_opened?)

      4 ->
        ctx
        |> mes("[Payon Guide]")
        |> mes("Be safe in")
        |> mes("your travels,")
        |> mes("brave adventurer.")
        |> close()

      _ ->
        main_menu(ctx, marking?, guide_opened?)
    end
  end

  defp offer_marks(ctx, true), do: {ctx, true}

  defp offer_marks(ctx, false) do
    {ctx, choice} =
      ctx
      |> mes("Would you like me")
      |> mes("to mark locations")
      |> mes("on your Mini-Map?")
      |> next()
      |> select(["Yes.", "No."])

    {ctx, choice == 1}
  end

  defp city_guide(ctx, marking?, paged?) do
    ctx = if paged?, do: next(ctx), else: ctx
    {ctx, choice} = select(ctx, Enum.map(@locations, &elem(&1, 0)) ++ ["Cancel"])

    case choice do
      choice when choice in 1..9 ->
        {_label, lines, {x, y, id, color}} = Enum.at(@locations, choice - 1)
        ctx = Enum.reduce(lines, mes(ctx, "[Payon Guide]"), &mes(&2, &1))
        ctx = if marking?, do: viewpoint(ctx, 1, x, y, id, color), else: ctx
        city_guide(ctx, marking?, true)

      10 ->
        ctx
        |> mes("[Payon Guide]")
        |> mes("Please ask me to ''Remove")
        |> mes("Marks from Mini-Map'' if you")
        |> mes("no longer wish to have the")
        |> mes("location marks displayed")
        |> mes("on your Mini-Map.")

      _ ->
        city_guide(ctx, marking?, true)
    end
  end

  defp clear_marks(ctx) do
    ctx
    |> viewpoint(2, 237, 41, 2, 0x00FF00)
    |> viewpoint(2, 237, 41, 3, 0x0000FF)
    |> viewpoint(2, 46, 345, 4, 0xFF00FF)
    |> viewpoint(2, 175, 220, 5, 0xFF0000)
    |> viewpoint(2, 175, 220, 6, 0xFF0000)
    |> viewpoint(2, 175, 220, 7, 0xFF0000)
    |> viewpoint(2, 237, 41, 8, 0x0000FF)
    |> viewpoint(2, 46, 345, 9, 0x00FF00)
    |> viewpoint(2, 175, 220, 10, 0xFF0000)
  end

  defp notice(ctx) do
    ctx
    |> mes("[Payon Guide]")
    |> mes("Advances in sorcery and")
    |> mes("technology have allowed")
    |> mes("us to update our information")
    |> mes("system, enabling up to mark")
    |> mes("locations on your Mini-Map")
    |> mes("for easier navigation.")
    |> next()
    |> mes("[Payon Guide]")
    |> mes("Your Mini-Map is located")
    |> mes("in the upper right corner")
    |> mes("of the screen. If you can't")
    |> mes("see it, press the Ctrl + Tab")
    |> mes("keys or click the ''Map'' button in your Basic Info Window.")
    |> next()
    |> mes("[Payon Guide]")
    |> mes("On your Mini-Map,")
    |> mes("click on the ''+'' and ''-''")
    |> mes("symbols to zoom in and")
    |> mes("our of your Mini-Map. We")
    |> mes("hope you enjoy your travels")
    |> mes("here in the city of Payon.")
  end
end
