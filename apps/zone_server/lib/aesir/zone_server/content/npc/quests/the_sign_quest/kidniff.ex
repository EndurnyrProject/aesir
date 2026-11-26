defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Kidniff do
  @moduledoc """
  Follows Alakina Ann's attempts to return home.

  ## Behavior

  - Responds to the player's progress in helping her find a way home.
  - Accepts the crow wings and advances her part of the quest.

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
        map: "nif_in",
        x: 156,
        y: 91,
        dir: 1,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#kidniff",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars

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
    {ctx, _} = FUpdatesignvars.call(ctx, [])

    if get_char_var(ctx, :sign_q, 0) == 83 do
      case get_char_var(ctx, :sign_sq, 0) do
        stage when stage in [0, 2] -> crying(ctx)
        1 -> offer_help(ctx)
        stage when stage in [3, 4] -> crow_wing(ctx)
        5 -> wing_failed(ctx)
        _ -> betrayed(ctx)
      end
    else
      crying(ctx)
    end
  end

  defp crying(ctx) do
    ctx
    |> mes("[Alakina Ann]")
    |> mes("^333333*Cries*^000000")
    |> mes("Where am I?")
    |> mes("I... I wanna go home~")
    |> emotion(:cry)
    |> close()
  end

  defp offer_help(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Alakina Ann]")
      |> mes("W-will you help me get")
      |> mes("back home? Please? I miss")
      |> mes("my mommy and my daddy and")
      |> mes("I don't know how I got here.")
      |> mes("^333333*Sniff*^000000")
      |> next()
      |> select(["What can I do?", "You can't go back..."])

    case choice do
      1 ->
        ctx
        |> mes("[Alakina Ann]")
        |> mes("I dunno. I-I think a ")
        |> mes("singing man told me to")
        |> mes("go meet a witch, but it's")
        |> mes("too scary to go outside...")
        |> set_char_var(:sign_sq, 2)
        |> close()

      2 ->
        ctx
        |> mes("[Alakina Ann]")
        |> mes("^333333*Sniff*^000000")
        |> mes("N-no...")
        |> mes("I wanna go home...")
        |> close2()
        |> emotion(:cry)

      _ ->
        ctx
    end
  end

  defp crow_wing(ctx) do
    if count_item(ctx, 7309) > 0 do
      ctx =
        ctx
        |> mes("[Alakina Ann]")
        |> mes("I... I can use")
        |> mes("this to go back home?")
        |> mes("Thank you! Thank you so much!")

      ctx
      |> delitem(7309, count_item(ctx, 7309))
      |> set_char_var(:sign_sq, 5)
      |> close()
    else
      ctx
      |> mes("[Alakina Ann]")
      |> mes("How am I gonna")
      |> mes("find that witch?")
      |> mes("She's the only one")
      |> mes("who knows how to")
      |> mes("get me back home...")
      |> mes("^333333*Cries*^000000")
      |> emotion(:cry)
      |> close()
    end
  end

  defp wing_failed(ctx) do
    ctx
    |> mes("[Alakina Ann]")
    |> mes("Y-you lied to me!")
    |> mes("This wing doesn't do")
    |> mes("anything! I-I'm still here")
    |> mes("in this scary place! ^333333*Cries*^000000")
    |> set_char_var(:sign_sq, 6)
    |> emotion(:cry)
    |> close()
  end

  defp betrayed(ctx) do
    ctx
    |> mes("[Alakina Ann]")
    |> mes("You said that you")
    |> mes("could help me get home,")
    |> mes("but you didn't help me")
    |> mes("at all. Y-you lied to me!")
    |> mes("I... I hate you! ^333333*Wah~!*^000000")
    |> emotion(:cry)
    |> close()
  end
end
