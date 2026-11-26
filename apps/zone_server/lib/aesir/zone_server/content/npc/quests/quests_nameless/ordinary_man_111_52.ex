defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.OrdinaryMan11152 do
  @moduledoc """
  Larjes shares information about a missing man.

  ## Behavior

  - Advances the investigation after discussing the kidnapping.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "cmd_in02",
        x: 111,
        y: 52,
        dir: 3,
        sprite: 97,
        name: "Ordinary Man",
        scope: :shared,
        unique_name: "Ordinary Man#pc2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :aru_monas, 0) < 3 ->
        ctx
        |> mes("[Larjes]")
        |> mes("^666666*Sigh...*^000000")
        |> mes("This isn't good at all.")
        |> mes("I don't know what to do...")
        |> close()

      get_char_var(ctx, :aru_monas, 0) == 3 ->
        discuss_investigation(ctx)

      true ->
        ctx
        |> mes("[Larjes]")
        |> mes("I gambled away")
        |> mes("this much money?")
        |> mes("How am I gonna pay")
        |> mes("off all of this debt?!")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp discuss_investigation(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Larjes]")
      |> mes("Good, no one should be")
      |> mes("able to hear us from here.")
      |> mes("After I sent a message to")
      |> mes("the place, I found some")
      |> mes("new information that should")
      |> mes("really help my investigation.")
      |> next()
      |> mes("[Larjes]")
      |> mes("I learned that two details")
      |> mes("about the night when that")
      |> mes("high ranking man vanished.")
      |> mes("Firstly, he left the guards for")
      |> mes("a bit to meet a woman. It's")
      |> mes("always a woman, isn't it?")
      |> next()
      |> mes("[Larjes]")
      |> mes("Secondly, after he left to")
      |> mes("meet that woman, some other")
      |> mes("people came in, and then they")
      |> mes("carried some really large")
      |> mes("baggage with them when")
      |> mes("they left to the west.")
      |> next()
      |> mes("[Larjes]")
      |> mes("Those bags were so big,")
      |> mes("it's suspicious. It seems")
      |> mes("like some organization has")
      |> mes("kidnapped him, and wants to")
      |> mes("bring him west for some reason.")
      |> next()
      |> select(["Why to the west?"])

    ctx
    |> mes("[Larjes]")
    |> mes("This is just a guess, but")
    |> mes("I think whoever kidnapped")
    |> mes("him are from ^2F4F2FArunafeltz^000000.")
    |> mes("I'm prohibited from entering")
    |> mes("Arunafeltz so I wasn't able")
    |> mes("to investigate any further.")
    |> set_char_var(:aru_monas, 4)
    |> close()
  end
end
