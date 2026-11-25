defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.Lusalka do
  @moduledoc """
  An unseen Lusalka stirs in the marsh.

  ## Behavior

  - Reveal Lusalka at night to visitors carrying holy water, or injure those without it.
  - Relay her request and grant her hair as the quest advances.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mosk_fild02",
        x: 116,
        y: 202,
        dir: 3,
        sprite: -1,
        name: "Lusalka",
        scope: :shared,
        unique_name: "Lusalka#07russai_22",
        trigger: {3, 3}
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
  def on_talk(ctx), do: ctx

  def ev_ontouch(ctx) do
    cond do
      get_char_var(ctx, :rhea_rus_main, 0) != 8 or get_char_var(ctx, :rhea_rus_hair, 0) < 2 ->
        emotion(ctx, :question, playerattached(ctx))

      get_char_var(ctx, :rhea_rus_hair, 0) == 2 ->
        night_encounter(ctx, 2)

      get_char_var(ctx, :rhea_rus_hair, 0) > 2 and get_char_var(ctx, :rhea_rus_hair, 0) < 7 ->
        ctx
        |> mes("[Lusalka's Voice]")
        |> mes(
          "His name is 'Igor'.. He has gone to the capital of Rune-Midgarts. Give him my golden earrings."
        )
        |> next()
        |> mes("[Lusalka's Voice]")
        |> mes("And please, tell him to stop suffering and to be happy. This is my request.")
        |> close()

      get_char_var(ctx, :rhea_rus_hair, 0) == 7 ->
        night_encounter(ctx, 7)

      get_char_var(ctx, :rhea_rus_hair, 0) == 8 ->
        collect_hair(ctx)

      get_char_var(ctx, :rhea_rus_hair, 0) > 8 ->
        watched(ctx)

      true ->
        ctx
    end
  end

  defp night_encounter(ctx, stage) do
    if gettime(ctx, 3) >= 17 or gettime(ctx, 3) <= 6 do
      ctx = ctx |> mes("- Splash !! -") |> next()

      case {stage, count_item(ctx, 523) > 0} do
        {2, true} ->
          ctx
          |> mes("- You hear a splashing sound -")
          |> mes("- and see something gleaming -")
          |> donpcevent("Lusalka#rus23::OnEnable")
          |> close()

        {2, false} ->
          ctx
          |> mes("- You hear a splashing as -")
          |> mes("- something gleaming -")
          |> mes("- seems to stare at you!! -")
          |> next()
          |> specialeffect2(:flasher)
          |> percent_heal(hp: -60, sp: 0)
          |> close()

        {7, true} ->
          ctx
          |> mes("-You hear splashing sound and see something gleaming-")
          |> donpcevent("Lusalka#rus23::OnEnable")
          |> close()

        {7, false} ->
          ctx
          |> mes("-You seem to hear the splash but something gleaming raids on you!!-")
          |> specialeffect2(:flasher)
          |> percent_heal(hp: -60, sp: 0)
          |> close()
      end
    else
      ctx
    end
  end

  defp collect_hair(ctx) do
    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("What was that?!")
      |> mes("Why am I here?")
      |> next()
      |> mes("- After standing up, you see -")
      |> mes("- the wet hair in front of you -")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("...This.. is Lusalka's hair?")
    |> mes("Ah, right.. I came here to get her hair.")
    |> next()
    |> mes("- You pick up the hair -")
    |> next()
    |> mes("- As soon as you touch the -")
    |> mes("- cool damp hair, you seem -")
    |> mes("- the feel the sadness within -")
    |> set_char_var(:rhea_rus_hair, 9)
    |> give_item(7878, 2)
    |> close()
  end

  defp watched(ctx) do
    ctx =
      ctx
      |> mes("- You feel that someone -")
      |> mes("- is watching you -")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Who's there? Anybody here?")
    |> next()
    |> mes("- The splashing sound -")
    |> mes("- fades away, but you -")
    |> mes("- still feel the sadness -")
    |> close()
  end
end
