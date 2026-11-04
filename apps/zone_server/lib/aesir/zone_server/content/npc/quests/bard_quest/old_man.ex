defmodule Aesir.ZoneServer.Content.Npc.Quests.BardQuest.OldMan do
  @moduledoc """
  Sketzi Bundin guards a collection of old songs.

  ## Behavior

  His dialogue and access to the collection depend on bard quest progress.

  ## Credits

  Original rAthena authors: Riotblade and L0ne_W0lf.
  Contributors: Lupus, SinSloth, and Euphy.

  ## Adaptation

  Transpiled by `mix aesir.import.npcs` and refactored with LLM assistance.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno_in01",
        x: 172,
        y: 100,
        dir: 3,
        sprite: 712,
        name: "Old Man",
        scope: :shared,
        unique_name: "Old Man#bq1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :gef_bard_q, 0) > 11 and get_char_var(ctx, :gef_bard_q, 0) < 20 do
      ctx
      |> mes("[Sketzi Bundin]")
      |> mes(
        "Well, did you find what you were seeking for? Although all we have are old, dusty books, I hope you come by to visit. And please give my regards to your Bard friends."
      )
      |> close()
    else
      if get_char_var(ctx, :gef_bard_q, 0) == 30 do
        ctx
        |> mes("[Sketzi Bundin]")
        |> mes("Interesting...")
        |> mes(
          "You have a black cross seal on your hand. Is Kitty still around? I'm glad to see he's still alive. If you're a friend of his, then you are most welcome here."
        )
        |> close()
      else
        if get_char_var(ctx, :gef_bard_q, 0) == 31 do
          ctx
          |> mes("[Sketzi Bundin]")
          |> mes(
            "Well, well, well. You're here again. So, what kind of books are you seeking today? Of course, all we have are old, dusty tomes full of eddas. Hahahaha~"
          )
          |> close()
        else
          if get_char_var(ctx, :gef_bard_q, 0) == 11 do
            {ctx, choice} =
              ctx
              |> mes("[Sketzi Bundin]")
              |> mes("Welcome.")
              |> mes(
                "You must be looking for something special. Well, we have almost every Norse poem, or 'edda.' This is the only place where you can find those kinds of old songs."
              )
              |> next()
              |> mes("[Sketzi Bundin]")
              |> mes(
                "However, I cannot show these fragile books to just anybody. For the sake of preservation, I can only show these works to preferred customers."
              )
              |> next()
              |> select(["Show him your left hand.", "Show him your right hand."])

            if choice == 1 do
              ctx
              |> mes("[Sketzi Bundin]")
              |> mes(
                "Ah~! You must be the friend of a high ranking Bard! I see, I see. You must be a friend of Minty Errende."
              )
              |> next()
              |> mes("[Sketzi Bundin]")
              |> mes(
                "So, what is it that you're looking for? Well, I suppose I don't really need to ask that. Hahahaha~"
              )
              |> next()
              |> mes("[Sketzi Bundin]")
              |> mes("Please...")
              |> mes("Take your time.")
              |> mes("I hope you find")
              |> mes("what you're")
              |> mes("looking for.")
              |> set_char_var(:gef_bard_q, 12)
              |> close()
            else
              ctx
              |> mes("[Sketzi Bundin]")
              |> mes("Let's see... Okay.")
              |> mes(
                "Well, your heartbeat is a little faster than normal. You might want to look into that. You know, for the sake of your health?"
              )
              |> next()
              |> mes("[Sketzi Bundin]")
              |> mes(
                "You're not looking for any medical or health related books, are you? I'm sorry, but we don't carry any of those."
              )
              |> close()
            end
          else
            ctx
            |> mes("[Sketzi Bundin]")
            |> mes("Welcome.")
            |> mes(
              "You must be looking for something special and rare. But we only carry one kind of book around here."
            )
            |> next()
            |> mes("[Sketzi Bundin]")
            |> mes(
              "If you're looking for monster information, why don't you check the Pronrera Library or the Monster Museum here in Juno?"
            )
            |> close()
          end
        end
      end
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
