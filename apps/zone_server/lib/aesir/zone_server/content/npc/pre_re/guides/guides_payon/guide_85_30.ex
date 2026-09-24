defmodule Aesir.ZoneServer.Content.Npc.PreRe.Guides.GuidesPayon.Guide8530 do
  @moduledoc """
  Archer Village guide who explains local destinations and mini-map marks.

  ## Behavior

  - Describes the Archer Guild, Tool Shop, and Payon Dungeon, optionally marking them.
  - Removes mini-map marks on request and explains mini-map controls.

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
        map: "pay_arche",
        x: 85,
        y: 30,
        dir: 2,
        sprite: 708,
        name: "Guide",
        scope: :pre_renewal,
        unique_name: "Guide#2pay"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @locations [
    {"^FF0000Archer Guild^000000",
     [
       "The Archer Guild,",
       "found northeast in",
       "the Archer Village,",
       "handles Job Changes",
       "to the Archer Class."
     ], {144, 164, 0, 0xFFFF00}},
    {"Tool Shop",
     ["You can find", "a Tool Shop in", "the northeast corner", "of the Archer Village."],
     {71, 156, 1, 0xFFFF00}},
    {"Payon Dungeon",
     ["The entrance to", "the Payon Dungeon", "is located at the west", "end of the village."],
     {34, 132, 2, 0xFFFFFF}}
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
      ctx |> next() |> select(["City Guide", "Remove Marks from Mini-Map", "Notice", "Cancel"])

    case choice do
      1 ->
        {ctx, marking?} =
          ctx
          |> mes("[Payon Guide]")
          |> mes("Please, select a menu.")
          |> offer_marks(marking?)

        ctx |> city_guide(marking?, guide_opened?) |> main_menu(marking?, true)

      2 ->
        ctx
        |> viewpoint(2, 237, 41, 0, 0xFF00FF)
        |> viewpoint(2, 237, 41, 1, 0xFF0000)
        |> viewpoint(2, 46, 345, 2, 0xFF00FF)
        |> main_menu(false, guide_opened?)

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
      |> mes("Would you like to leave indicators on the mini-map?")
      |> next()
      |> select(["Yes.", "No."])

    {ctx, choice == 1}
  end

  defp city_guide(ctx, marking?, paged?) do
    ctx = if paged?, do: next(ctx), else: ctx
    {ctx, choice} = select(ctx, Enum.map(@locations, &elem(&1, 0)) ++ ["Cancel"])

    case choice do
      choice when choice in 1..3 ->
        {_label, lines, {x, y, id, color}} = Enum.at(@locations, choice - 1)
        ctx = Enum.reduce(lines, mes(ctx, "[Payon Guide]"), &mes(&2, &1))
        ctx = if marking?, do: viewpoint(ctx, 1, x, y, id, color), else: ctx
        city_guide(ctx, marking?, true)

      4 ->
        ctx
        |> mes("[Payon Guide]")
        |> mes(
          "If you'd like to erase the marks on the mini-map, select menu, 'Wipe all indicators on the mini-map'."
        )

      _ ->
        city_guide(ctx, marking?, true)
    end
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
