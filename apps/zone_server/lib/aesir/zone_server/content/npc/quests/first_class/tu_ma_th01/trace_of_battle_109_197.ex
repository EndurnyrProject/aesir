defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuMaTh01.TraceOfBattle109197 do
  @moduledoc """
  Reveals clues from a mysterious battle to Thieves and Mages following its trail.

  ## Behavior

  - Reveals poison traps, allows their investigation and dismantling, and uncovers bloodstained cloth.

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
        map: "moc_fild18",
        x: 109,
        y: 197,
        dir: 0,
        sprite: 844,
        name: "Trace of Battle",
        scope: :shared,
        unique_name: "Trace of Battle#15"
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
        |> mes("^3355FFThese look like")
        |> mes("traces of some kind")
        |> mes("of pursuit or battle, but")
        |> mes("you can't really tell for sure.^000000")
        |> close()

      get_char_var(ctx, :tu_thief01, 0) < 21 and Rathena.truthy?(get_local(ctx, :class_thief, 0)) ->
        ctx
        |> mes("^3355FFThere are signs")
        |> mes("showing that a lot")
        |> mes("of people were in")
        |> mes("this area earlier.^000000")
        |> close()

      get_char_var(ctx, :tu_magician01, 0) < 21 and
          Rathena.truthy?(get_local(ctx, :class_mage, 0)) ->
        mes(ctx, "A large group of people seem to have gone by.") |> close()

      (get_char_var(ctx, :tu_thief01, 0) == 21 and
         Rathena.truthy?(get_local(ctx, :class_thief, 0))) or
          (get_char_var(ctx, :tu_magician01, 0) == 21 and
             Rathena.truthy?(get_local(ctx, :class_mage, 0))) ->
        discover_poison_traps(ctx)

      (get_char_var(ctx, :tu_thief01, 0) == 22 and
         Rathena.truthy?(get_local(ctx, :class_thief, 0))) or
          (get_char_var(ctx, :tu_magician01, 0) == 22 and
             Rathena.truthy?(get_local(ctx, :class_mage, 0))) ->
        investigate_poison_traps(ctx)

      true ->
        cond do
          (get_char_var(ctx, :tu_thief01, 0) == 23 and
             Rathena.truthy?(get_local(ctx, :class_thief, 0))) or
              (get_char_var(ctx, :tu_magician01, 0) == 23 and
                 Rathena.truthy?(get_local(ctx, :class_mage, 0))) ->
            dismantle_poison_trap(ctx)

          (get_char_var(ctx, :tu_thief01, 0) == 24 and
             Rathena.truthy?(get_local(ctx, :class_thief, 0))) or
              (get_char_var(ctx, :tu_magician01, 0) == 24 and
                 Rathena.truthy?(get_local(ctx, :class_mage, 0))) ->
            ctx =
              ctx
              |> mes("^3355FFInside the dismantled")
              |> mes("trap, you find another")
              |> mes("piece of strange cloth")
              |> mes("that's stained with blood.")
              |> mes("You take it with you in")
              |> mes("hopes that it provides")
              |> mes("some kind of evidence.^000000")

            if get_char_var(ctx, :tu_thief01, 0) == 24 do
              set_char_var(ctx, :tu_thief01, 25)
            else
              set_char_var(ctx, :tu_magician01, 25)
            end

          true ->
            ctx
            |> mes("^3355FFYou examine the area")
            |> mes("a little further and guess")
            |> mes("that the battle might head")
            |> mes("towards the south.^000000")
        end
        |> close()
    end
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

  defp discover_poison_traps(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFThis area is clearly")
      |> mes("marked with signs")
      |> mes("of a violent battle, with")
      |> mes("traces of poison strewn")
      |> mes("all over the ground.^000000")
      |> next()
      |> select(["Continue following the traces.", "Further investigate the area."])

    case choice do
      1 ->
        ctx
        |> mes("^3355FFYou examine the")
        |> mes("trail, but can't really")
        |> mes("discern the direction")
        |> mes("in which the battle")
        |> mes("continues...^000000")
        |> close()

      2 ->
        ctx =
          ctx
          |> mes("^3355FFYou find a bunch of")
          |> mes("traps that use different")
          |> mes("kinds of poison. The ones")
          |> mes("that have been set off are")
          |> mes("mixed with the ones which")
          |> mes("haven't been triggered.^000000")

        if get_char_var(ctx, :tu_thief01, 0) == 21 do
          set_char_var(ctx, :tu_thief01, 22)
        else
          set_char_var(ctx, :tu_magician01, 22)
        end
        |> close()

      _ ->
        close(ctx)
    end
  end

  defp investigate_poison_traps(ctx) do
    if Enum.random(1..3) == 3 do
      {ctx, choice} =
        ctx
        |> mes("^3355FFOne trap in particular")
        |> mes("stands out to you more")
        |> mes("than the rest. Perhaps")
        |> mes("you should pour some")
        |> mes("Green Potion on it to")
        |> mes("neutralize it first.^000000")
        |> next()
        |> select(["Pour Green Potion.", "Don't use Green Potion."])

      case choice do
        1 ->
          if count_item(ctx, 506) < 1 do
            ctx
            |> mes("^3355FFUnfortunately, you")
            |> mes("don't have a Green")
            |> mes("Potion that you can")
            |> mes("use to pour on this trap...^000000")
            |> close()
          else
            ctx =
              ctx
              |> mes("^3355FFPouring that")
              |> mes("Green Potion didn't")
              |> mes("really make anything")
              |> mes("happen. Perhaps you")
              |> mes("should try something else.^000000")
              |> delitem(506, 1)

            if get_char_var(ctx, :tu_thief01, 0) == 22 do
              set_char_var(ctx, :tu_thief01, 23)
            else
              set_char_var(ctx, :tu_magician01, 23)
            end
            |> close()
          end

        2 ->
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("I guess...")
          |> mes("I'll try investigating")
          |> mes("this area a little more?")
          |> close()

        _ ->
          close(ctx)
      end
    else
      ctx
      |> mes("^3355FFBy sheer accident,")
      |> mes("you set off one of")
      |> mes("the traps in the area.^000000")
      |> sc_start(:sc_poison, 60000, 0)
      |> specialeffect(:venomdust2)
      |> percent_heal(hp: -30, sp: 0)
      |> close()
    end
  end

  defp dismantle_poison_trap(ctx) do
    cond do
      count_item(ctx, 511) > 0 and count_item(ctx, 716) > 0 ->
        ctx =
          ctx
          |> mes("^3355FFYou try grinding")
          |> mes("a Green Herb and")
          |> mes("sprinkling it on the")
          |> mes("trap and then place")
          |> mes("a Red Gemstone on it.")
          |> mes("The gem glows and")
          |> mes("slowly melts away...^000000")
          |> next()
          |> mes("^3355FFAlthough you don't")
          |> mes("fully understand the")
          |> mes("science of using poisons")
          |> mes("or antidotes, you managed")
          |> mes("to successfully dismantle")
          |> mes("the trap. Now you can safely")
          |> mes("check what might be inside.^000000")
          |> delitem(511, 1)
          |> delitem(716, 1)

        if get_char_var(ctx, :tu_thief01, 0) == 23 do
          set_char_var(ctx, :tu_thief01, 24)
        else
          set_char_var(ctx, :tu_magician01, 24)
        end

      count_item(ctx, 511) > 0 ->
        ctx
        |> mes("^3355FFYou should try to")
        |> mes("dismantle this trap")
        |> mes("by using other catalysts")
        |> mes("related to the curing or")
        |> mes("use of poison. You do have")
        |> mes("a Green Herb on you, so you")
        |> mes("try sprinkling it on the trap.^000000")
        |> next()
        |> mes("^3355FFHowever, nothing")
        |> mes("happens. It seems that")
        |> mes("you need another catalyst")
        |> mes("in addition to the Green Herb")
        |> mes("that you have in order to")
        |> mes("dismantle this trap.^000000")

      count_item(ctx, 716) > 0 ->
        ctx
        |> mes("^3355FFYou should try to")
        |> mes("dismantle this trap")
        |> mes("by using other catalysts")
        |> mes("related to the curing or use")
        |> mes("of poison. You do have a")
        |> mes("Red Gemstone, so you grind")
        |> mes("it and sprinkle it on the trap.^000000")
        |> next()
        |> mes("^3355FFHowever, nothing")
        |> mes("happens. It seems that")
        |> mes("you need another catalyst to")
        |> mes("use with the Red Gemstone")
        |> mes("that you have in order to")
        |> mes("dismantle this trap.^000000")

      true ->
        ctx
        |> mes("^3355FFYou should try to")
        |> mes("dismantle this trap")
        |> mes("by using other catalysts")
        |> mes("related to the curing or")
        |> mes("use of poison. But what")
        |> mes("items should you bring?^000000")
    end
  end
end
