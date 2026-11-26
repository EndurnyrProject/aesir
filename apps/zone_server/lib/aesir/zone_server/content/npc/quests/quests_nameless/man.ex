defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Man do
  @moduledoc """
  A fallen man conceals the Dead King.

  ## Behavior

  - Touching him during the investigation summons the Dead King and hides the man.
  - The death event enables the corpse; the timer restores the encounter.

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
        map: "abbey03",
        x: 232,
        y: 233,
        dir: 4,
        sprite: 956,
        name: "Man",
        scope: :shared,
        unique_name: "Man#King"
      }
    ]

  @impl true
  def on_event("OnMyMobDead", ctx) do
    ctx |> stopnpctimer() |> donpcevent("Dead Man#King::OnEnable")
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTimer300000", ctx) do
    ctx |> stopnpctimer() |> hideonnpc("Dead Man#King") |> hideoffnpc("Man#King")
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :aru_monas, 0) < 22 ->
        ctx
        |> mes("^3355FFYou find a man lying on")
        |> mes("the floor, wearing torn")
        |> mes("yet luxurious clothing.")
        |> mes("He doesn't seem to be")
        |> mes("breathing at all...^000000.")
        |> next()
        |> mes("^3355FFHe's dead.^000000")
        |> close()

      get_char_var(ctx, :aru_monas, 0) == 22 or get_char_var(ctx, :aru_monas, 0) == 23 ->
        {ctx, choice} =
          ctx
          |> mes("^3355FFYou find a man lying on")
          |> mes("the floor, wearing torn")
          |> mes("yet luxurious clothing.")
          |> mes("He doesn't seem to be")
          |> mes("breathing at all...^000000.")
          |> next()
          |> mes("^3355FFYou bring your ears more")
          |> mes("closely to his mouth: it")
          |> mes("seems that he really is")
          |> mes("still barely alive.^000000")
          |> next()
          |> select(["Touch Him", "Ignore Him"])

        if choice == 1 do
          ctx
          |> mes("[#{char_name(ctx, 0)}]")
          |> mes("This man...")
          |> mes("He's so familiar")
          |> mes("for some reason.")
          |> next()
          |> mes("^3355FFAs you touch him, the")
          |> mes("man suddenly jumps")
          |> mes("up with a crazed yowl.^000000")
          |> set_char_var(:aru_monas, 23)
          |> summon_mob(
            mob_id: 1875,
            map: "abbey03",
            at: {232, 232},
            name: "Dead King",
            event: "Man#King::OnMyMobDead"
          )
          |> initnpctimer()
          |> hideonnpc("Man#King")
          |> close()
        else
          ctx
          |> mes("^3355FFYou don't feel")
          |> mes("comfortable enough")
          |> mes("to touch this man.^000000")
          |> close()
        end

      true ->
        ctx |> mes("^3355FFHe's dead... Now...^000000") |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
