defmodule Aesir.ZoneServer.Content.Npc.Floating.Cities.Lutie.MrClaus do
  @moduledoc """
  Mr. Claus, the Santa in Al De Baran who sends players to Lutie.

  ## Behavior

  - Tells the player about the Christmas town of Lutie, or transports them to
    the Lutie fields free of charge.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lemongrass

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script cities/lutie.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "aldebaran",
        x: 168,
        y: 168,
        dir: 4,
        sprite: 718,
        name: "Mr. Claus",
        scope: :renewal,
        unique_name: "Mr. Claus#1"
      },
      %{
        map: "aldebaran",
        x: 223,
        y: 222,
        dir: 4,
        sprite: 718,
        name: "Mr. Claus",
        scope: :pre_renewal,
        unique_name: "Mr. Claus#1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Mr. Claus]")
      |> mes("Ho Ho Ho~")
      |> mes("Merry Christmas!!")
      |> mes("I wish all of you joy")
      |> mes("and Christmas cheer!")
      |> next()
      |> select(["Info about Lutie", "Move to 'Lutie'", "Cancel"])

    case choice do
      1 -> describe_lutie(ctx)
      2 -> send_to_lutie(ctx)
      3 -> merry_christmas(ctx)
      _ -> ctx
    end
  end

  defp describe_lutie(ctx) do
    ctx
    |> mes("[Mr. Claus]")
    |> mes(
      "^3355FFLutie^000000, the fantastic Christmas Town! Always filled with the spirit of giving, Lutie is filled with appetizing cakes, tiny toy soldiers, and all sorts of wonderful things~!"
    )
    |> next()
    |> mes("[Mr. Claus]")
    |> mes("Ho Ho Ho~")
    |> mes(
      "It's an amazing land blessed with the beauty of winter, and a year round atmosphere of festivity!"
    )
    |> next()
    |> mes("[Mr. Claus]")
    |> mes(
      "I'm a Santa that will guide people to Lutie, the Christmas Town. Ask me at any time, and I'll magically send you there~"
    )
    |> close()
  end

  defp send_to_lutie(ctx) do
    ctx
    |> mes("[Mr. Claus]")
    |> mes("Ho Ho Ho~")
    |> mes("The only way to get to Lutie is here in Al de Baran!")
    |> next()
    |> mes("[Mr. Claus]")
    |> mes(
      "I keep this place and personally transport people who want to visit Lutie. Please ask Santa Claus over there if you want to leave town. He will let you know the way out of Lutie."
    )
    |> next()
    |> mes("[Mr. Claus]")
    |> mes("Ho Ho Ho~")
    |> mes("Well, are you ready?")
    |> mes("Have a nice trip!")
    |> mes("Meeeeerry Christmas!")
    |> close()
    |> warp("xmas_fild01", 78, 68)
  end

  defp merry_christmas(ctx) do
    ctx
    |> mes("[Mr. Claus]")
    |> mes("Ho Ho Ho~")
    |> mes(
      "Whenever you want to visit Lutie, be my guest. Just let me know when you want to leave."
    )
    |> next()
    |> mes("[Mr. Claus]")
    |> mes("Ho ho hooooo!!")
    |> mes("Haaaaappy Holidays!")
    |> close()
  end
end
