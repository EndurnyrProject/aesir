defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuMaTh01.TraceOfBattle do
  @moduledoc """
  Reveals clues from a mysterious battle to Thieves and Mages following its trail.

  ## Behavior

  - Starts the trail southward and exposes unprepared Thieves to poison.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Jukka (fix up)
    - Lupus
    - L0ne_W0lf
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "moc_fild12",
        x: 166,
        y: 369,
        dir: 0,
        sprite: 844,
        name: "Trace of Battle",
        scope: :shared,
        unique_name: "Trace of Battle#1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = read_class_locals(ctx)

    cond do
      (get_local(ctx, :class_thief, 0) == 0 and get_local(ctx, :class_mage, 0) == 0) or
          Rathena.truthy?(:erlang.band(eaclass(ctx), 2_097_152)) ->
        ctx
        |> mes("^3355FFThere are signs that show")
        |> mes("that some violent scuffle")
        |> mes("might have occurred here,")
        |> mes("but you can't tell what had")
        |> mes("happened exactly...^000000")

      (get_char_var(ctx, :tu_thief01, 0) < 5 and Rathena.truthy?(get_local(ctx, :class_thief, 0))) or
          (Rathena.truthy?(get_local(ctx, :class_mage, 0)) and
             get_char_var(ctx, :tu_magician01, 0) < 8) ->
        ctx =
          ctx
          |> mes("^3355FFYou find traces of poison")
          |> mes("used in a battle. You sense")
          |> mes("its potency and decide not")
          |> mes("to get too close to it.^000000")

        if Rathena.truthy?(get_local(ctx, :class_mage, 0)) do
          specialeffect(ctx, :venomdust2)
        else
          ctx
        end

      get_char_var(ctx, :tu_thief01, 0) == 5 and Rathena.truthy?(get_local(ctx, :class_thief, 0)) ->
        ctx
        |> mes("^3355FFYou find traces of poison")
        |> mes("used in a battle. A feeling")
        |> mes("of acute dizziness overcomes")
        |> mes("you after examining the scene.^000000")
        |> set_char_var(:tu_thief01, 6)
        |> sc_start(:sc_poison, 60000, 0)
        |> specialeffect(:venomdust2)

      get_char_var(ctx, :tu_thief01, 0) == 6 and Rathena.truthy?(get_local(ctx, :class_thief, 0)) ->
        ctx
        |> mes("^3355FFYou find traces of poison")
        |> mes("used in a battle. A feeling")
        |> mes("of acute dizziness overcomes")
        |> mes("you after examining the scene.^000000")
        |> sc_start(:sc_poison, 60000, 0)
        |> specialeffect(:venomdust2)

      get_char_var(ctx, :tu_thief01, 0) == 7 and Rathena.truthy?(get_local(ctx, :class_thief, 0)) ->
        ctx
        |> mes("^3355FFYou find traces of poison")
        |> mes("used in a battle. You sense")
        |> mes("its potency and decide not")
        |> mes("to get too close to it.^000000")

      (Rathena.truthy?(get_local(ctx, :class_thief, 0)) and get_char_var(ctx, :tu_thief01, 0) == 8) or
          (Rathena.truthy?(get_local(ctx, :class_mage, 0)) and
             get_char_var(ctx, :tu_magician01, 0) == 8) ->
        ctx =
          ctx
          |> mes("^3355FFThere are traces of a battle")
          |> mes("that seem to be leading in")
          |> mes("different directions. From the")
          |> mes("peculiar smell that permeates")
          |> mes("the area, it seems that some")
          |> mes("kind of lethal poison was used.^000000")
          |> next()
          |> mes("^3355FFStill...")
          |> mes("The trail of this")
          |> mes("battle decidedly")
          |> mes("heads southward.^000000")

        if get_char_var(ctx, :tu_magician01, 0) == 8 do
          set_char_var(ctx, :tu_magician01, 9)
        else
          set_char_var(ctx, :tu_thief01, 9)
        end

      true ->
        ctx
        |> mes("^3355FFYou find signs of")
        |> mes("a heated pursuit")
        |> mes("that head south.")
    end
    |> close()
  end

  defp read_class_locals(ctx) do
    ctx =
      set_local(
        ctx,
        :class_thief,
        Rathena.bool_int(Rathena.job_id(base_class(ctx)) == Rathena.job_id(:thief))
      )

    set_local(
      ctx,
      :class_mage,
      Rathena.bool_int(Rathena.job_id(base_class(ctx)) == Rathena.job_id(:mage))
    )
  end
end
