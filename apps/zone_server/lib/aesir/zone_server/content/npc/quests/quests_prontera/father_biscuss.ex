defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsProntera.FatherBiscuss do
  @moduledoc """
  Father Biscuss guides the investigation into the princes’ deaths.

  ## Behavior

  - Shares information according to quest progress and awards experience after the investigation.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Silent
    - Evera
    - Samuray22
    - SinSloth
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
        map: "prt_church",
        x: 184,
        y: 110,
        dir: 3,
        sprite: 60,
        name: "Father Biscuss",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :prt_curse, 0) do
      54 ->
        ctx
        |> mes("[Father Biscuss]")
        |> mes("Hmm, I still suspect that")
        |> mes("someone from the Assassin")
        |> mes("Guild may have killed the")
        |> mes("princes. Just in case, I'm")
        |> mes("going to send a spy. Keep")
        |> mes("that information secret.")
        |> next()
        |> mes("[Father Biscuss]")
        |> mes("So yes. You didn't learn")
        |> mes("or hear anything from us,")
        |> mes("and you don't know anything")
        |> mes("about the royal family's curse.")
        |> mes("From here on, Father Bamph")
        |> mes("and I will handle this issue.")
        |> close()

      35 ->
        ctx =
          ctx
          |> mes("[Father Biscuss]")
          |> mes("I've never seen Father")
          |> mes("Bamph this way before, but")
          |> mes("I can understand how he feels.")
          |> mes("As one of the leaders of this")
          |> mes("church, he feels responsible")
          |> mes("for these princes' deaths.")
          |> next()
          |> mes("[Father Biscuss]")
          |> mes("I'm sure he'll feel")
          |> mes("better in a few days,")
          |> mes("but right now, he's in no")
          |> mes("condition to compile the")
          |> mes("valuable info that you've")
          |> mes("provided, so I'll do it.")
          |> next()
          |> mes("[Father Biscuss]")
          |> mes("Personally, I feel that")
          |> mes("what happened was tragic,")
          |> mes("but it should be avenged.")
          |> mes("Perhaps that why I've held")
          |> mes("a grudge against Imbullea")
          |> mes("for all this time. Anyway...")
          |> next()
          |> mes("[Father Biscuss]")
          |> mes("Although we can't")
          |> mes("acknowledge it publicly,")
          |> mes("on behalf of the Prontera")
          |> mes("Church, I want to thank")
          |> mes("you for all of your help.")
          |> set_char_var(:prt_curse, 36)

        ctx
        |> getexp(if(Rathena.truthy?(checkre(ctx, 3)), do: 90_000, else: 1_600_000), 0)
        |> close()

      36 ->
        ctx
        |> mes("[Father Biscuss]")
        |> mes("No one can know light")
        |> mes("without experiencing")
        |> mes("darkness. Peace has")
        |> mes("no meaning until it is")
        |> mes("contrasted with chaos.")
        |> next()
        |> mes("[Father Biscuss]")
        |> mes("Religion becomes even")
        |> mes("more important during times")
        |> mes("of chaos, and times of need.")
        |> mes("I must remain calm, especially")
        |> mes("when Father Bamph feels so bad about this whole incident...")
        |> close()

      _ ->
        ctx
        |> mes("[Father Biscuss]")
        |> mes("Please observe")
        |> mes("silence within the")
        |> mes("Priest Room. Thank")
        |> mes("you for cooperating.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
