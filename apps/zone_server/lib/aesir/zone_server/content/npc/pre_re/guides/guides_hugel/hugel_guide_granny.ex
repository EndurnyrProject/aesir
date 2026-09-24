defmodule Aesir.ZoneServer.Content.Npc.PreRe.Guides.GuidesHugel.HugelGuideGranny do
  @moduledoc """
  Hugel village guide who describes local amenities and attractions.

  ## Behavior

  - Describes village destinations and optionally marks them on the mini-map.
  - Removes marks on request and explains mini-map controls.

  ## Credits

  - Original from rAthena, authors and Contributors
    - erKURITA
    - L0ne_W0lf
    - Silent

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "hugel",
        x: 98,
        y: 56,
        dir: 3,
        sprite: 863,
        name: "Hugel Guide Granny",
        scope: :pre_renewal,
        unique_name: "Hugel Guide Granny#huge",
        trigger: {0, 0}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @locations [
    {"Church",
     ["Well, to me, this Church is rather like a place for old folks like me, you know..."],
     {156, 116, 2, 0xFF0000}},
    {"Inn",
     [
       "Pudding rather than praise.",
       "You'd better unpack your stuffs first before you start looking around this village.",
       "It is the building right next to me."
     ], {104, 79, 3, 0xFF00FF}},
    {"Pub",
     [
       "Yes, when you travel, you want to drop by a pub and make new friends.",
       "Go east from here, then you will arrive at the pub."
     ], {129, 66, 4, 0x99FFFF}},
    {"Airport",
     [
       "A while ago, strangers came to village and built that strange airport kind of thing...",
       "What do they call it? Airship?"
     ], {178, 146, 5, 0x0000FF}},
    {"Weapon Shop",
     [
       "Well, we have a weapon shop in the center of village.",
       "But I don't know if there is any weapon that you find useful."
     ], {70, 158, 6, 0x00FF00}},
    {"Tool Shop",
     [
       "Yes, I love Hugel brand Red Potions. I haven't tasted Red Potions from any other brands yet...hohoho. ",
       "The tool shop is located in the center of village."
     ], {93, 167, 7, 0x00FF00}},
    {"Party Supplies Shop",
     [
       "The party supplies shop is around the center of village.",
       "Make sure that you will not use any firecracker stuffs near other people, because it is dangerous, you know?"
     ], {91, 105, 8, 0xFF99FF}},
    {"^3131FFHunter Job Change Place^000000",
     [
       "Oh, are you an aspiring Hunter?",
       "Then head northeast following the beach, then you will find the Hunter job change place."
     ], {206, 228, 9, 0xFF9900}},
    {"^3131FFShrine Expedition's Place^000000",
     [
       "I heard that the shrine expedition is staying in a house at the west.",
       "They have put some kind of sign in the middle of village, so I guess that they are hiring people for something...",
       "I wonder what they are doing in here...hmmm."
     ], {52, 91, 10, 0xFFFFFF}},
    {"Monster Race Arena",
     [
       "I also like playing Monster Race games. It is pretty fun, you know?",
       "Oh, you haven't tried it yet? No~ you'd better try. Trust me, you will like it."
     ], {58, 72, 11, 0xFF9900}},
    {"Bingo Game Room",
     ["Do you like bingo games? If you do, go visit Euklan's Bingo Game Room."],
     {55, 209, 12, 0x66FFFF}}
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Hugel Guide Granny]")
    |> mes("Oh, hello~ you are one energetic adventurer.")
    |> mes("Welcome to Hugel. I was honored to guide you to this beautiful village.")
    |> mes(
      "If this is the first time for you to use the guide services, why don't you check the ''Notice'' menu first?"
    )
    |> main_menu(false, false)
  end

  defp main_menu(ctx, marking?, guide_opened?) do
    {ctx, choice} =
      ctx |> next() |> select(["Village Guide", "Remove Marks from Mini-Map", "Notice", "Cancel"])

    case choice do
      1 ->
        {ctx, marking?} =
          ctx
          |> mes("[Hugel Guide Granny]")
          |> mes("I can tell you any building location as long as it is in Hugel.")
          |> mes("So where do you want to go?")
          |> offer_marks(marking?)

        ctx |> village_guide(marking?, guide_opened?) |> main_menu(marking?, true)

      2 ->
        ctx |> clear_marks() |> main_menu(false, guide_opened?)

      3 ->
        ctx |> notice() |> main_menu(marking?, guide_opened?)

      4 ->
        ctx
        |> mes("[Hugel Guide Granny]")
        |> mes("This guide job is pretty exciting. Hohoho~")
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

  defp village_guide(ctx, marking?, paged?) do
    ctx = if paged?, do: next(ctx), else: ctx
    {ctx, choice} = select(ctx, Enum.map(@locations, &elem(&1, 0)) ++ ["Cancel"])

    case choice do
      choice when choice in 1..11 ->
        {_label, lines, {x, y, id, color}} = Enum.at(@locations, choice - 1)
        ctx = Enum.reduce(lines, mes(ctx, "[Hugel Guide Granny]"), &mes(&2, &1))
        ctx = if marking?, do: viewpoint(ctx, 1, x, y, id, color), else: ctx
        village_guide(ctx, marking?, true)

      12 ->
        ctx
        |> mes("[Hugel Guide Granny]")
        |> mes("If you like to get rid of all the location marks on your Mini-Map,")
        |> mes("just ask me again, and choose ''Remove Marks from Mini-Map'' menu.")

      _ ->
        village_guide(ctx, marking?, true)
    end
  end

  defp clear_marks(ctx) do
    ctx =
      Enum.reduce(@locations, ctx, fn {_label, _lines, {x, y, id, color}}, ctx ->
        viewpoint(ctx, 2, x, y, id, color)
      end)

    ctx
    |> mes("[Hugel Guide Granny]")
    |> mes("Okay, they are gone now. If you have more locations to ask, just let me know.")
  end

  defp notice(ctx) do
    ctx
    |> mes("[Hugel Guide Granny]")
    |> mes("When you are using the ''Village Guide'' menu, ")
    |> mes(
      "make sure that building locations will be marked on your mini-map at the upper right side of your screen."
    )
    |> mes(
      "If you cannot see your mini-map, use the short cut key ''ctrl+tab'' or press the ''Map'' button on your basic information windows, okay?"
    )
    |> mes(
      "And you can also zoom out your mini-map by using the ''-'' button in case you cannot view the entire map of the village."
    )
  end
end
