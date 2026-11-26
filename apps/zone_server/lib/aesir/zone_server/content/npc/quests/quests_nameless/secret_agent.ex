defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.SecretAgent do
  @moduledoc """
  Helps the player sail to the monastery.

  ## Behavior

  - At the appropriate quest stage, offers passage and hides after departure.

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
        map: "ve_fild07",
        x: 128,
        y: 130,
        dir: 1,
        sprite: 97,
        name: "Secret Agent",
        scope: :shared,
        unique_name: "Secret Agent#Aru"
      }
    ]

  @impl true
  def on_event("OnInit", ctx) do
    ev_oninit(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :aru_monas, 0) == 16 do
      {ctx, choice} =
        ctx
        |> mes("[Larjes]")
        |> mes("Are you ready to go")
        |> mes("aboard? I'll help you")
        |> mes("sail to that monastery,")
        |> mes("but if you fail while you're")
        |> mes("there, I might not be here")
        |> mes("when you come back.")
        |> next()
        |> select(["Yes, I'm ready.", "Give me more time."])

      case choice do
        1 ->
          ctx
          |> mes("[Larjes]")
          |> mes("Alright, let's go.")
          |> mes("Hold on to something:")
          |> mes("this will probably be")
          |> mes("a pretty rocky ride...")
          |> set_char_var(:aru_monas, 17)
          |> close2()
          |> hideonnpc("Secret Agent#Aru")
          |> warp("nameless_i", 257, 217)

        2 ->
          ctx
          |> mes("[Larjes]")
          |> mes("Alright. Just let me know")
          |> mes("whenever you're ready.")
          |> close()

        _ ->
          ctx
      end
    else
      ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_oninit(ctx), do: hideonnpc(ctx, "Secret Agent#Aru")
end
