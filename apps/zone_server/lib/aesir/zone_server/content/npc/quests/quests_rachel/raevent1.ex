defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Raevent1 do
  @moduledoc """
  A spring that recalls the tragedy of Bruspetti.

  ## Behavior

  - Advances the investigation as the player visits the spring.
  - Completes the quest and grants experience after the final reflection.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "rachel",
        x: 265,
        y: 47,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#raevent1",
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnTouch_", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ontouch(ctx) do
    case get_char_var(ctx, :rach_vice, 0) do
      23 -> reflect_on_tragedy(ctx)
      22 -> learn_about_spring(ctx)
      8 -> remember_warning(ctx)
      7 -> receive_warning(ctx)
      _ -> ctx
    end
  end

  defp reflect_on_tragedy(ctx) do
    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Just looking at this")
      |> mes("spring makes me think")
      |> mes("of Bruspetti. What really")
      |> mes("happened to her? I get")
      |> mes("the feeling that she")
      |> mes("caved in to despair.")
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("The water's not that")
      |> mes("cold, or very deep...")
      |> mes("And Katinshuell mentioned")
      |> mes("that her body went limp...")
      |> mes("But she was still looking")
      |> mes("at him. It's haunting...")
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("I suppose she was torn...")
      |> mes("She loved him, but couldn't")
      |> mes("bear to live with his secret.")
      |> mes("In the end, it's all so very")
      |> mes("tragic. Katinshuell isn't")
      |> mes("really a bad person...")
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("He was forced to")
      |> mes("commit a heinous crime,")
      |> mes("and kept making mistakes,")
      |> mes("running from his guilt. Is")
      |> mes("anyone accountable for this?")
      |> mes("Who would be to blame?")
      |> next()
      |> set_char_var(:rach_vice, 24)
      |> completequest(8122)

    experience =
      if Rathena.truthy?(checkre(ctx, 3)) do
        cond do
          base_level(ctx) > 90 -> 130_000
          base_level(ctx) > 75 -> 85_000
          true -> 45_000
        end
      else
        cond do
          base_level(ctx) > 90 -> 1_300_000
          base_level(ctx) > 75 -> 850_000
          true -> 450_000
        end
      end

    ctx
    |> getexp(experience, 0)
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Somehow, I wish that")
    |> mes("Katinshuell had the")
    |> mes("strength to face his")
    |> mes("guilt, and then to")
    |> mes("forgive himself.")
    |> close()
  end

  defp learn_about_spring(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("This must be where")
    |> mes("Bruspetti drowned...")
    |> next()
    |> mes("[Grandma]")
    |> mes("Oh! Excuse me,")
    |> mes("young adventurer,")
    |> mes("but you mustn't stand")
    |> mes("there! It's very slippery.")
    |> mes("What if you fall into the")
    |> mes("spring? It's dangerous.")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Oh... Er, thank you.")
    |> mes("Yes, I wouldn't want")
    |> mes("to get myself drowned.")
    |> next()
    |> set_char_var(:rach_vice, 23)
    |> mes("[Grandma]")
    |> mes("Drowned...? I just")
    |> mes("wouldn't want you to")
    |> mes("get your clothes wet.")
    |> mes("The water isn't that deep...")
    |> mes("Even if you can't swim, you")
    |> mes("can climb out, you know.")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("...What?")
    |> close()
  end

  defp remember_warning(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("That old woman told")
    |> mes("be to be careful not to")
    |> mes("slip and fall into the water")
    |> mes("around here, so I'd better")
    |> mes("make sure I tread carefully.")
    |> close()
  end

  defp receive_warning(ctx) do
    ctx
    |> mes("[???]")
    |> mes("Oh, be very careful!")
    |> mes("You don't want to get")
    |> mes("too close to the water.")
    |> mes("What if you slip and fall?")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Huh?")
    |> next()
    |> mes("[Grandma]")
    |> mes("Oh, I'm sorry if")
    |> mes("I startled you, but the")
    |> mes("ground that you're standing")
    |> mes("on is very slippery, you know.")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Ah, I see.")
    |> set_char_var(:rach_vice, 8)
    |> changequest(8111, 8112)
    |> close()
  end
end
