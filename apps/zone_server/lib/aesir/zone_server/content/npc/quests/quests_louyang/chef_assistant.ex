defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.ChefAssistant do
  @moduledoc """
  A martial artist who works as a chef assistant.

  ## Behavior

  - May catch players attempting to steal the soup.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - Lupus
    - SinSloth
    - L0ne_W0lf
    - Paradox924X
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lou_in02",
        x: 58,
        y: 183,
        dir: 5,
        sprite: 823,
        name: "Chef Assistant",
        scope: :shared,
        unique_name: "Chef Assistant#lou1",
        trigger: {5, 5}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Jin Wei Ling]")
    |> mes("I used to be")
    |> mes("an enthusiastic")
    |> mes("martial artist.")
    |> next()
    |> mes("[Jin Wei Ling]")
    |> mes("Although I became an")
    |> mes("assistant chef for a living, I always think of myself as a martial artist first.")
    |> next()
    |> mes("[Jin Wei Ling]")
    |> mes(
      "So, I decided to reflect the spirit of the martial arts into my cooking. We are often very busy when there are many customers."
    )
    |> next()
    |> mes("[Jin Wei Ling]")
    |> mes(
      "When we're busy, I can use my martial arts to cook cuisine much more quickly! Hahaha~ Martial arts can be very practical!"
    )
    |> next()
    |> specialeffect(:beginspell3)
    |> mes("[Jin Wei Ling]")
    |> mes("Waaa-!!!!")
    |> next()
    |> specialeffect(:endure)
    |> mes("[Jin Wei Ling]")
    |> mes("Waaa Taaah-!!!!!")
    |> next()
    |> specialeffect(:sonicblow)
    |> mes("[Jin Wei Ling]")
    |> mes("Waaa...")
    |> mes("Waaa Taaah-!!!!!")
    |> next()
    |> specialeffect(:sonicblowhit)
    |> mes("^3355FF* Chop chop chop chop chop *^000000")
    |> next()
    |> emotion(:best)
    |> mes("[Jin Wei Ling]")
    |> mes("Hahahaha! Look these perfect vergetable slices! Muhahahaha!!")
    |> mes("I will continue to hone my martial arts through cooking!")
    |> close()
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :ch_tre, 0) == 2 or get_char_var(ctx, :ch_tre, 0) == 3 do
      threshold =
        cond do
          gettime(ctx, 3) >= 10 and gettime(ctx, 3) < 14 -> 9
          gettime(ctx, 3) >= 14 and gettime(ctx, 3) < 17 -> 10
          gettime(ctx, 3) >= 17 and gettime(ctx, 3) < 22 -> 6
          true -> nil
        end

      if threshold && Enum.random(1..10) < threshold do
        ctx
        |> mes("[Jin Wei Ling]")
        |> mes("Wait! Who are you!")
        |> mes("Put that pot down")
        |> mes("and get out of")
        |> mes("here right now!")
        |> next()
        |> mes("^3131FFYou have failed^000000")
        |> mes("^3131FFto steal the pot.^000000")
        |> set_char_var(:ch_tre, 1)
        |> close()
      else
        ctx
      end
    else
      ctx
    end
  end
end
