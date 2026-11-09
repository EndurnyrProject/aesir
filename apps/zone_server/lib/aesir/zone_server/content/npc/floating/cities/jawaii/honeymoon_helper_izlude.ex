defmodule Aesir.ZoneServer.Content.Npc.Floating.Cities.Jawaii.HoneymoonHelperIzlude do
  @moduledoc """
  Honeymoon Helper who offers couples the trip to the Jawaii resort.

  ## Behavior

  - Answers questions about Jawaii or, for a party of two, sells the trip for
    100,000 zeny and warps the couple to the island.
  - Players without a partner are turned away, and couples short of the fare
    are told to save up.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Daegaladh
    - Masao
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script cities/jawaii.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "izlude",
        x: 180,
        y: 224,
        dir: 3,
        sprite: 71,
        name: "Honeymoon Helper",
        scope: :renewal,
        unique_name: "Honeymoon Helper#Izlude"
      },
      %{
        map: "izlude_a",
        x: 180,
        y: 224,
        dir: 3,
        sprite: 71,
        name: "Honeymoon Helper",
        scope: :renewal,
        unique_name: "Honeymoon Helper#Iz_a"
      },
      %{
        map: "izlude_b",
        x: 180,
        y: 224,
        dir: 3,
        sprite: 71,
        name: "Honeymoon Helper",
        scope: :renewal,
        unique_name: "Honeymoon Helper#Iz_b"
      },
      %{
        map: "izlude_c",
        x: 180,
        y: 224,
        dir: 3,
        sprite: 71,
        name: "Honeymoon Helper",
        scope: :renewal,
        unique_name: "Honeymoon Helper#Iz_c"
      },
      %{
        map: "izlude_d",
        x: 180,
        y: 224,
        dir: 3,
        sprite: 71,
        name: "Honeymoon Helper",
        scope: :renewal,
        unique_name: "Honeymoon Helper#Iz_d"
      },
      %{
        map: "izlude",
        x: 171,
        y: 185,
        dir: 3,
        sprite: 71,
        name: "Honeymoon Helper",
        scope: :pre_renewal,
        unique_name: "Honeymoon Helper#Izlude"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @fare 100_000

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Helper]")
      |> mes("Newlyweds and")
      |> mes("long time couples...")
      |> mes("We invite you to Jawaii,")
      |> mes("the honeymoon resort!")
      |> next()
      |> select(["Jawaii?", "Let's go to Jawaii~!", "Cancel."])

    case choice do
      1 -> describe_jawaii(ctx)
      2 -> travel_to_jawaii(ctx)
      3 -> describe_the_offer(ctx)
      _ -> ctx
    end
  end

  defp describe_jawaii(ctx) do
    ctx
    |> mes("[Helper]")
    |> mes("There is an island far, far away from the Midgard continent.")
    |> mes("It is a very quiet and beautiful island resort that only opens")
    |> mes("its doors to couples.")
    |> next()
    |> mes("[Helper]")
    |> mes(
      "This is an exclusive travel offer to the special honeymoon resort for Midgard's citizens. The price, 100,000 zeny, may be expensive, but you really get what you pay for."
    )
    |> next()
    |> mes("[Helper]")
    |> mes("I guarantee you that some of")
    |> mes("the happiest moments you can")
    |> mes(
      "experience in your marriage will be on this island. Can you really put a price on that?"
    )
    |> close()
  end

  defp travel_to_jawaii(ctx) do
    ctx = mes(ctx, "[Helper]")

    cond do
      not Rathena.truthy?(getpartnerid(ctx)) ->
        ctx
        |> mes("Errm...")
        |> mes(
          "Unfortunately, singles are not allowed on the island. Why don't you go forget your loneliness in the Prontera pub?"
        )
        |> close()

      zeny(ctx) > 99_999 ->
        ctx
        |> pay_zeny(@fare)
        |> mes("Bon Voyage...!!")
        |> mes("Let me guide")
        |> mes("you to 'Jawaii!'")
        |> close()
        |> warp("jawaii", 245, 125)

      true ->
        ctx
        |> mes(
          "As I explained, you must have 100,000 zeny in order to visit Jawaii. Why don't you ask your partner for help in gathering the zeny for this trip?"
        )
        |> close()
    end
  end

  defp describe_the_offer(ctx) do
    ctx
    |> mes("[Helper]")
    |> mes(
      "There's there no better way to share special, secluded moments with your beloved than through"
    )
    |> mes("a secret trip to a remote, exotic area.")
    |> next()
    |> mes("[Helper]")
    |> mes(
      "A vacation in Jawaii could very well be the greatest gift that you could give to the one you love~"
    )
    |> close()
  end
end
