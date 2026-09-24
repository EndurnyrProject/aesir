defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Monk.DoorKeeper do
  @moduledoc """
  Guards the Monk test halls and waves candidates through.

  ## Behavior

  - Hints where to find Boohae for candidates looking for him.
  - Lets candidates in the middle of their tests go inside.
  - Asks everyone else to be quiet inside.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Dino9021
    - Celest
    - L0ne_W0lf
    - Samuray22
    - Kisuka
    - Lupus
    - Yor
    - Zephiris
    - Vicious
    - Silent

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_monk",
        x: 199,
        y: 169,
        dir: 3,
        sprite: 746,
        name: "Door Keeper",
        scope: :shared,
        unique_name: "Door Keeper#mk"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Keeper Chorip]")
      |> mes("....this place is for those")
      |> mes(" in testing for becoming a monk.")
      |> next()

    quest = get_char_var(ctx, :MONK_Q, 0)

    cond do
      quest == 14 ->
        ctx
        |> mes("[Keeper Chorip]")
        |> mes("Huh? Did you just say Boohae?")
        |> next()
        |> mes("[Keeper Chorip]")
        |> mes(
          "Boohae... tends to hide in some quite places, so you might not be able to find him. For instance... a corner..."
        )
        |> close()

      quest > 14 and quest < 25 ->
        confirm_candidate(ctx)

      true ->
        ctx |> mes("[Keeper Chorip]") |> mes("...please be quiet inside.") |> close()
    end
  end

  defp confirm_candidate(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Keeper Chorip]")
      |> mes(Rathena.concat(Rathena.concat("Is your name ", char_name(ctx, 0)), "?"))
      |> next()
      |> select(["Yes.", "No."])

    if choice == 1 do
      ctx
      |> mes("[Keeper Chorip]")
      |> mes("Alright you're cool... go on in. Your test is waiting for you. Good luck.")
      |> close()
    else
      ctx
      |> mes("[Keeper Chorip]")
      |> mes("Yeah right, I know who you are... get in there... your test is ready.")
      |> close()
    end
  end
end
