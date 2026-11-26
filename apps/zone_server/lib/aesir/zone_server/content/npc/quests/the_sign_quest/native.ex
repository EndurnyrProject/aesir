defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Native do
  @moduledoc """
  Laotan trades a clue for a Mr. Smile mask.

  ## Behavior

  - Offers a quest clue in exchange for the mask after the language quest.

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
        map: "umbala",
        x: 163,
        y: 256,
        dir: 3,
        sprite: 781,
        name: "Native",
        scope: :shared,
        unique_name: "Native#_s"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])

    if get_char_var(ctx, :event_umbala, 0) >= 3 do
      ctx = mes(ctx, "[Laotan]")

      cond do
        get_char_var(ctx, :sign_q, 0) < 73 ->
          ctx
          |> mes("Oh, I wish I had")
          |> mes("a Mr. Smile mask!")
          |> mes("But where can I get")
          |> mes("one of those? Well, I'd")
          |> mes("be happy if I had some")
          |> mes("Meat to eat, I guess!")
          |> emotion(:delight)
          |> close()

        get_char_var(ctx, :sign_q, 0) == 73 ->
          ctx =
            ctx
            |> mes("Mmm...?")
            |> mes("A new guy in our village?")
            |> mes("I think I know him! Yea, I do!")
            |> next()
            |> mes("[Laotan]")

          if count_item(ctx, 2278) > 0 do
            {ctx, choice} =
              ctx
              |> mes("Oh my gosh!")
              |> mes("You've got a Mr. Smile mask!")
              |> mes("Would you give that to me?")
              |> mes("Pretty please...?")
              |> next()
              |> select(["Sure~", "^FF0000No.^000000"])

            case choice do
              1 ->
                ctx
                |> mes("[Laotan]")
                |> mes("Hooooray!")
                |> mes("Thank you thank you")
                |> mes("thank you thank you")
                |> mes("soooooooooo much!")
                |> next()
                |> mes("[Laotan]")
                |> mes("Oh right~!")
                |> mes(
                  "The weird man in the funny clothes was in our village for a while, but ever since he went into that big tree, nobody's seen him!"
                )
                |> delitem(2278, 1)
                |> set_char_var(:sign_q, 74)
                |> close()

              2 ->
                ctx
                |> mes("[Laotan]")
                |> mes("I...")
                |> mes("I was...")
                |> mes("I just...")
                |> mes("Waaaaaaahhhh!")
                |> close()

              _ ->
                ctx
            end
          else
            ctx
            |> mes("Waaaait.")
            |> mes("I knooow~!")
            |> mes("I know if you get")
            |> mes("me a Mr. Smile, okay?")
            |> close()
          end

        true ->
          ctx
          |> mes("I love my Mr. Smile mask")
          |> mes("soooo much! I'm gonna show")
          |> mes("it to all my friends! Thank you")
          |> mes("so much again! You're really")
          |> mes("really nice, you know that?")
          |> close()
      end
    else
      ctx
      |> mes("[??????]")
      |> mes("Chuuuba?")
      |> mes("Chu-chu-chu-chu-chaba?")
      |> mes("Oom oom oom daba. Blip blip?")
      |> mes("Sabaloo koombah Solo. Ho ho~")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
