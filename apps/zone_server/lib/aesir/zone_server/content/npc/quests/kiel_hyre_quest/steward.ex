defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Steward do
  @moduledoc """
  The steward controls access to Kiel Hyre and Mitchell inside the mansion.

  ## Behavior

  - Admits invited visitors and turns away players without sufficient quest progress.
  - Offers transfers to Kiel Hyre or Mitchell according to the ordered quest gates.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "kh_mansion",
        x: 78,
        y: 55,
        dir: 5,
        sprite: 109,
        name: "Steward",
        scope: :shared,
        unique_name: "Steward#kh"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    quest = get_char_var(ctx, :KielHyreQuest, 0)

    cond do
      quest < 46 ->
        ctx
        |> mes("[Steward]")
        |> mes("This is a private residence,")
        |> mes("please leave.")
        |> close()
        |> warp("lighthalzen", 188, 201)

      quest < 50 ->
        check_invitation(ctx)

      (quest >= 50 and quest < 64) or quest >= 70 ->
        offer_master(ctx)

      quest == 52 or quest == 54 or (quest >= 64 and quest <= 70) ->
        offer_hosts(ctx)

      true ->
        ctx
    end
  end

  defp check_invitation(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Steward]")
      |> mes("Greetings.")
      |> mes("Have you been invited")
      |> mes("by the master of")
      |> mes("this mansion?")
      |> next()
      |> select(["Present Golden Key", "????"])

    case choice do
      1 ->
        ctx = mes(ctx, "[Steward]")

        ctx
        |> mes("Ah, Master #{char_name(ctx, 0)}.")
        |> mes("I've been expecting your")
        |> mes("arrival. Please, this way.")
        |> close()
        |> warp("kh_mansion", 21, 14)

      2 ->
        ctx
        |> mes("[Steward]")
        |> mes("If you have not been")
        |> mes("invited by the master of")
        |> mes("this mansion, then I'm")
        |> mes("afraid that I must insist on")
        |> mes("your immediate departure!")
        |> close()
        |> warp("lighthalzen", 188, 201)

      _ ->
        ctx
    end
  end

  defp offer_master(ctx) do
    ctx = mes(ctx, "[Steward]")

    {ctx, choice} =
      ctx
      |> mes("Ah, Master #{char_name(ctx, 0)}.")
      |> mes("It is a pleasure to")
      |> mes("receive your company")
      |> mes("once again. Would you")
      |> mes("like to see my master?")
      |> next()
      |> select(["Yes", "No"])

    case choice do
      1 ->
        visit_master(ctx)

      2 ->
        ctx
        |> mes("[Steward]")
        |> mes("Very well.")
        |> mes("Please make")
        |> mes("yourself at home.")
        |> close()

      _ ->
        ctx
    end
  end

  defp offer_hosts(ctx) do
    ctx = mes(ctx, "[Steward]")

    {ctx, choice} =
      ctx
      |> mes("Ah, Master #{char_name(ctx, 0)}.")
      |> mes("It is a pleasure to")
      |> mes("receive your company")
      |> mes("once again. Would you")
      |> mes("like to see my master, or...?")
      |> next()
      |> select(["^FF0000Kiel Hyre^000000", "^3355FFMitchell^000000"])

    case choice do
      1 ->
        visit_master(ctx)

      2 ->
        ctx
        |> mes("[Steward]")
        |> mes("Oh...? You must.")
        |> mes("be here to deliver")
        |> mes("good news. Excuse me...")
        |> next()
        |> mes("^3355FFThe Steward furtively^000000")
        |> mes("^3355FFlooked around to check^000000")
        |> mes("^3355FFif anyone is watching him.^000000")
        |> next()
        |> mes("[Steward]")
        |> mes("I believe it should")
        |> mes("be safe enough to let")
        |> mes("you go see him now...")
        |> mes("Please, hurry this way.")
        |> close()
        |> warp("kh_mansion", 20, 87)

      _ ->
        ctx
    end
  end

  defp visit_master(ctx) do
    ctx
    |> mes("[Steward]")
    |> mes("Very well.")
    |> mes("Right this way~")
    |> close()
    |> warp("kh_mansion", 21, 14)
  end
end
