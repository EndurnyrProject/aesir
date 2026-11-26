defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.PiruPiru do
  @moduledoc """
  Piru Piru discusses her master's research.

  ## Behavior

  - Her dialogue changes with the time of day and quest progress.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "aldeba_in",
        x: 156,
        y: 118,
        dir: 4,
        sprite: 102,
        name: "Piru Piru",
        scope: :shared,
        unique_name: "Piru Piru#sign"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])
    ctx = mes(ctx, "[Piru Piru]")

    cond do
      gettime(ctx, 3) >= 12 and gettime(ctx, 3) <= 24 ->
        if get_char_var(ctx, :sign_q, 0) == 17 do
          {ctx, choice} =
            ctx
            |> emotion(:cry)
            |> mes("Oh, I'm sooo tired~")
            |> mes("But we can't sleep yet.")
            |> mes("*Sob* Master, can't we")
            |> mes("just call it a day already?")
            |> next()
            |> select([
              "What do you do in here?",
              "About vanished Alchemists",
              "What is the Stone of Sage?"
            ])

          case choice do
            1 ->
              research_dialogue(ctx)

            2 ->
              ctx
              |> mes("[Piru Piru]")
              |> mes("Oh, the father and daughter")
              |> mes(
                "who were both Alchemists, right? Did you know they vanished because they invented the monster potion summoning skill?"
              )
              |> next()
              |> mes("[Piru Piru]")
              |> mes("Their discovery caused")
              |> mes("such great hysteria in the")
              |> mes("scientific community. In the")
              |> mes("end they had no choice but")
              |> mes("to live in seclusion deep")
              |> mes("in the ^CE3131forest to the south^000000.")
              |> next()
              |> mes("[Piru Piru]")
              |> mes("They devoted their lives")
              |> mes("to their research, just like")
              |> mes("my master. If he makes a major")
              |> mes("breakthrough, we'll have to")
              |> mes("disappear like they did...")
              |> close()

            3 ->
              ctx
              |> mes("[Piru Piru]")
              |> mes("Hmm? Well, I wouldn't")
              |> mes("know anything about that.")
              |> mes("In fact, I'm always staying")
              |> mes("in this lab, so I never hear")
              |> mes("any rumors or news outside.")
              |> close()

            _ ->
              ctx
          end
        else
          {ctx, _} =
            ctx
            |> emotion(:cry)
            |> mes("Oh, I'm sooo tired~")
            |> mes("But we can't sleep yet.")
            |> mes("*Sob* Master, can't we")
            |> mes("just call it a day already?")
            |> next()
            |> select(["What do you do in here?"])

          research_dialogue(ctx)
        end

      gettime(ctx, 3) >= 6 and gettime(ctx, 3) < 12 ->
        ctx
        |> mes("Everyday we study and")
        |> mes("take notes and test and")
        |> mes("experiment and record")
        |> mes("results and... Horrible!")
        |> next()
        |> mes("[Piru Piru]")
        |> mes(
          "Although my master and I are the only ones who use this lab, we do have a set working schedule. We work from 10 AM to 5 PM and have our free time from 5 PM to 10 PM, which is when Master goes to bed."
        )
        |> next()
        |> mes("[Piru Piru]")
        |> mes("Of course, Master")
        |> mes("is happy if he can")
        |> mes("just do more research.")
        |> mes("In any case, please visit")
        |> mes("us after 5 PM if you have")
        |> mes("any business with us.")
        |> close()

      true ->
        {ctx, choice} =
          ctx
          |> mes("....Zzz...Zzz...")
          |> mes("Zzz....Zzz......")
          |> next()
          |> select(["Wake her up", "Leave her sleep"])

        case choice do
          1 ->
            ctx
            |> mes("[Piru Piru]")
            |> mes("Wh-wha...?")
            |> mes("Why do you gotta")
            |> mes("wake me up? Come back")
            |> mes("after 10:00 AM tomorrow, kay?")
            |> close()

          2 ->
            ctx |> mes("[Piru Piru]") |> mes("Zzzz.....Zzzzz...") |> close()

          _ ->
            ctx
        end
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp research_dialogue(ctx) do
    ctx
    |> mes("[Piru Piru]")
    |> mes("My master, Sir Jore,")
    |> mes("is researching a way to")
    |> mes("create artificial life! Still,")
    |> mes("it's not easy and we haven't")
    |> mes("accomplished anything yet...")
    |> next()
    |> mes("[Piru Piru]")
    |> mes("It doesn't help that my")
    |> mes("master spends all of his")
    |> mes("time on research. He hasn't")
    |> mes("been taking care of himself")
    |> mes("and is losing a lot of weight.")
    |> mes("I'm really worried about him.")
    |> close()
  end
end
