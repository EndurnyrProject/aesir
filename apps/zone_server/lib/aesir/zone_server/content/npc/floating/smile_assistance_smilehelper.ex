defmodule Aesir.ZoneServer.Content.Npc.Floating.SmileAssistanceSmilehelper do
  @moduledoc """
  Smile Assistance girls of the Rune-Midgarts national event, who trade a Mr. Smile mask.

  ## Behavior

  - Explains the Mr. Smile campaign, or takes 10 Jellopy, 10 Fluff and 10 Clover
    for a Mr. Smile mask, or says goodbye.
  - Refuses the trade with a reminder of the three requirements while any of the
    stacks is short.
  - Placed in every town of both modes; the renewal-only duplicates cover the
    rebuilt Izlude and Morocc.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Akaru
    - L0ne_W0lf
    - Samuray22
    - Lupus
    - Daegaladh
    - Masao
    - Euphy
    - zackdreaver

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/mrsmile.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "alberta",
        x: 113,
        y: 53,
        dir: 4,
        sprite: 92,
        name: "Smile Assistance",
        unique_name: "Smile Assistance#alb"
      },
      %{
        map: "aldebaran",
        x: 136,
        y: 135,
        dir: 4,
        sprite: 92,
        name: "Smile Assistance",
        unique_name: "Smile Assistance#alde"
      },
      %{
        map: "geffen",
        x: 119,
        y: 107,
        dir: 4,
        sprite: 92,
        name: "Smile Assistance",
        unique_name: "Smile Assistance#gef"
      },
      %{
        map: "moc_ruins",
        x: 59,
        y: 154,
        dir: 3,
        sprite: 92,
        name: "Smile Assistance",
        unique_name: "Smile Assistance#moc"
      },
      %{
        map: "payon",
        x: 186,
        y: 104,
        dir: 5,
        sprite: 92,
        name: "Smile Assistance",
        unique_name: "Smile Assistance#pay"
      },
      %{
        map: "prontera",
        x: 157,
        y: 187,
        dir: 4,
        sprite: 92,
        name: "Smile Assistance",
        unique_name: "Smile Assistance#prt"
      },
      %{
        map: "izlude",
        x: 125,
        y: 175,
        dir: 4,
        sprite: 92,
        name: "Smile Assistance",
        unique_name: "Smile Assistance#iz",
        scope: :renewal
      },
      %{
        map: "izlude_a",
        x: 125,
        y: 175,
        dir: 4,
        sprite: 92,
        name: "Smile Assistance",
        unique_name: "Smile Assistance#iz_a",
        scope: :renewal
      },
      %{
        map: "izlude_b",
        x: 125,
        y: 175,
        dir: 4,
        sprite: 92,
        name: "Smile Assistance",
        unique_name: "Smile Assistance#iz_b",
        scope: :renewal
      },
      %{
        map: "izlude_c",
        x: 125,
        y: 175,
        dir: 4,
        sprite: 92,
        name: "Smile Assistance",
        unique_name: "Smile Assistance#iz_c",
        scope: :renewal
      },
      %{
        map: "izlude_d",
        x: 125,
        y: 175,
        dir: 4,
        sprite: 92,
        name: "Smile Assistance",
        unique_name: "Smile Assistance#iz_d",
        scope: :renewal
      },
      %{
        map: "morocc",
        x: 159,
        y: 107,
        dir: 4,
        sprite: 92,
        name: "Smile Assistance",
        unique_name: "Smile Assistance#moc2",
        scope: :renewal
      },
      %{
        map: "izlude",
        x: 129,
        y: 118,
        dir: 4,
        sprite: 92,
        name: "Smile Assistance",
        unique_name: "Smile Assistance#iz",
        scope: :pre_renewal
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @jellopy 909
  @fluff 914
  @clover 705
  @mr_smile 2278

  @requirements [
    "^3355FF10 Jellopy^000000",
    "^3355FF10 Fluff^000000",
    "^3355FF10 Clover^000000"
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Smile Girl]")
      |> mes("Hi ~ Hi ~")
      |> mes("This is Smile Assistance.")
      |> mes("How may I help you ?")
      |> next()
      |> select(["^3355FFMr. Smile^000000 ?", "Construct ^3355FFMr. Smile^000000 ", "Quit"])

    case choice do
      1 -> explain_event(ctx)
      2 -> trade(ctx)
      3 -> farewell(ctx)
      _ -> ctx
    end
  end

  defp explain_event(ctx) do
    ctx
    |> mes("[Smile Girl]")
    |> mes("National Event held by the command of ^5577FFHis majesty Tristram the 3rd^000000,")
    |> mes("that intends to encourage the nation of the Rune-Midgarts Kingdom")
    |> mes(" to play in more enjoyable atmosphere!")
    |> mes("I am ^3355FF' Smile Assistance '^000000,")
    |> mes(".. who leads the national event under the name of ")
    |> mes("^3355FFSmile throughout the Rune-Midgarts Kingdom~^000000")
    |> next()
    |> mes("[Smile Girl]")
    |> mes("With simple and easy-to-get items,")
    |> mes("I can provide you")
    |> mes("^3355FF' Mr. Smile '^000000.")
    |> mes("The requirements are followings.")
    |> next()
    |> mes("[Smile Girl]")
    |> say(@requirements)
    |> next()
    |> mes("[Smile Girl]")
    |> mes("With this event")
    |> mes("Everybody will be happy and smile,")
    |> mes("getting together with other people,")
    |> mes("And will try to make Ragnarok the most enjoyable game in the world.")
    |> close()
  end

  defp trade(ctx) do
    if count_item(ctx, @jellopy) > 9 and count_item(ctx, @fluff) > 9 and
         count_item(ctx, @clover) > 9 do
      hand_over(ctx)
    else
      short(ctx)
    end
  end

  defp hand_over(ctx) do
    ctx
    |> mes("[Smile Girl]")
    |> mes("Congratulations !")
    |> mes("Now please take this Mr.Smile.")
    |> next()
    |> delitem(@jellopy, 10)
    |> delitem(@fluff, 10)
    |> delitem(@clover, 10)
    |> give_item(@mr_smile, 1)
    |> mes("[Smile Girl]")
    |> mes("His majesty,Tristram the 3rd")
    |> mes("has promised to try his best to make Ragnarok better and more enjoyable.")
    |> next()
    |> mes("The fact mentioned above")
    |> mes("was announced by")
    |> mes("the Public Information Bureau of the Rune-Midgarts Kingom.")
    |> close()
  end

  defp short(ctx) do
    ctx
    |> mes("[Smile Girl]")
    |> mes("Oh - unfortunately")
    |> mes("You have not brought")
    |> mes("enough items for Mr. Smile.")
    |> say(@requirements)
    |> mes("Please check the requirements above.")
    |> close()
  end

  defp farewell(ctx) do
    ctx
    |> mes("[Smile Girl]")
    |> mes("Thank you for visiting us.")
    |> mes("We ..")
    |> mes("The Rune-Midgarts Kingdom")
    |> mes("always try to make Ragnarok")
    |> mes("better and more enjoyable game.")
    |> next()
    |> mes("[Smile Girl]")
    |> mes("We sincerely ask you")
    |> mes("to cooperate.")
    |> mes("The fact mentioned above")
    |> mes("was announced by the Public Information Bureau of the Rune-Midgarts Kingom.")
    |> close()
  end

  defp say(ctx, lines), do: Enum.reduce(lines, ctx, fn line, ctx -> mes(ctx, line) end)
end
