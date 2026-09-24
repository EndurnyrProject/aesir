defmodule Aesir.ZoneServer.Content.Npc.PreRe.Guides.GuidesIzlude.Guide do
  @moduledoc """
  Izlude guide who directs visitors to the town's facilities.

  ## Behavior

  - Describes local destinations and optionally marks their locations on the mini-map.
  - Clears location marks on request and explains how to use the mini-map.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - MasterOfMuppets
    - erKURITA
    - Samuray22

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "izlude",
        x: 121,
        y: 87,
        dir: 6,
        sprite: 105,
        name: "Guide",
        scope: :pre_renewal,
        unique_name: "Guide#iz"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @locations [
    {"^FF0000Swordman Association^000000",
     [
       "The Swordman Association",
       "is located on an island that is",
       "in west Izlude. If you're thinking of changing jobs to Swordman,",
       "you should check it out."
     ], [{52, 140, 0, 0xFF0000}]},
    {"Swordman Hall",
     ["The Swordman Hall", "is located in the eastern", "island connected to Izlude."],
     [{214, 130, 1, 0x00FF00}]},
    {"Arena", ["Izlude's famous", "Arena is located at the", "northern end of Izlude."],
     [{128, 225, 2, 0x00FF00}]},
    {"Izlude Marina",
     [
       "You can find the",
       "Marina in the northeast",
       "part of Izlude. There, you can",
       "ride a ship which will take you",
       "to Alberta or Byalan Island."
     ], [{200, 180, 3, 0xFF0000}]},
    {"Weapon Shop", ["You can easily", "find the Weapon Shop", "in northwest Izlude."],
     [{111, 149, 4, 0xFF00FF}]},
    {"Tool Shop",
     ["The Tool Shop shouldn't", "be too hard to find in the", "northeast part of Izlude."],
     [{148, 148, 5, 0xFF00FF}]}
  ]

  @location_count length(@locations)
  @location_menu Enum.map(@locations, &elem(&1, 0)) ++ ["Cancel"]

  @cleared_marks [
    {237, 41, 0, 0x00FF00},
    {237, 41, 1, 0x0000FF},
    {46, 345, 2, 0x00FF00},
    {175, 220, 3, 0xFF0000},
    {134, 221, 4, 0xFF0000},
    {204, 214, 5, 0xFF0000}
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> cutin("prt_soldier", 2)
    |> mes("[Izlude Guide]")
    |> mes("Welcome to Izlude,")
    |> mes("Prontera's satellite city.")
    |> mes("If you need any guidance")
    |> mes("around Izlude, feel free")
    |> mes("to ask me at anytime.")
    |> main_menu(false, false)
    |> cutin("prt_soldier", 255)
  end

  defp main_menu(ctx, marking?, guide_opened?) do
    {ctx, choice} =
      ctx |> next() |> select(["City Guide", "Remove Marks from Mini-Map", "Notice.", "Cancel"])

    case choice do
      1 ->
        {ctx, marking?} =
          ctx
          |> mes("[Izlude Guide]")
          |> mes("Please select")
          |> mes("a location from")
          |> mes("the following menu.")
          |> offer_marks(marking?)

        ctx |> city_guide(marking?, guide_opened?) |> main_menu(marking?, true)

      2 ->
        ctx |> clear_marks() |> main_menu(false, guide_opened?)

      3 ->
        ctx |> explain_mini_map() |> main_menu(marking?, guide_opened?)

      4 ->
        ctx
        |> mes("[Izlude Guide]")
        |> mes("Okay then, feel")
        |> mes("free to come to me")
        |> mes("if you ever feel lost")
        |> mes("around Izlude, alright?")
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
      |> select(["Yes", "No"])

    {ctx, choice == 1}
  end

  defp city_guide(ctx, marking?, paged?) do
    ctx = if paged?, do: next(ctx), else: ctx
    {ctx, choice} = select(ctx, @location_menu)

    case choice do
      choice when choice in 1..@location_count ->
        {_label, lines, marks} = Enum.at(@locations, choice - 1)
        ctx |> describe(lines) |> mark(marking?, marks) |> city_guide(marking?, true)

      choice when choice == @location_count + 1 ->
        ctx
        |> mes("[Izlude Guide]")
        |> mes("Please ask me to ''Remove")
        |> mes("Marks from Mini-Map'' if you")
        |> mes("no longer wish to have the")
        |> mes("location marks displayed")
        |> mes("on your Mini-Map.")

      _ ->
        city_guide(ctx, marking?, true)
    end
  end

  defp describe(ctx, lines), do: Enum.reduce(lines, mes(ctx, "[Izlude Guide]"), &mes(&2, &1))

  defp mark(ctx, false, _marks), do: ctx

  defp mark(ctx, true, marks) do
    Enum.reduce(marks, ctx, fn {x, y, id, color}, ctx -> viewpoint(ctx, 1, x, y, id, color) end)
  end

  defp clear_marks(ctx) do
    Enum.reduce(@cleared_marks, ctx, fn {x, y, id, color}, ctx ->
      viewpoint(ctx, 2, x, y, id, color)
    end)
  end

  defp explain_mini_map(ctx) do
    ctx
    |> mes("[Izlude Guide]")
    |> mes("Advances in sorcery and")
    |> mes("technology have allowed")
    |> mes("us to update our information")
    |> mes("system, enabling up to mark")
    |> mes("locations on your Mini-Map")
    |> mes("for easier navigation.")
    |> next()
    |> mes("[Izlude Guide]")
    |> mes("Your Mini-Map is located")
    |> mes("in the upper right corner")
    |> mes("of the screen. If you can't")
    |> mes("see it, press the Ctrl + Tab")
    |> mes("keys or click the ''Map'' button in your Basic Info Window.")
    |> next()
    |> mes("[Izlude Guide]")
    |> mes("On your Mini-Map,")
    |> mes("click on the ''+'' and ''-''")
    |> mes("symbols to zoom in and")
    |> mes("our of your Mini-Map. We")
    |> mes("hope you enjoy your travels")
    |> mes("here in the city of Izlude.")
  end
end
