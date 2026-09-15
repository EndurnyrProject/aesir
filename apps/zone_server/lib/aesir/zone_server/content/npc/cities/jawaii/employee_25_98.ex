defmodule Aesir.ZoneServer.Content.Npc.Cities.Jawaii.Employee2598 do
  @moduledoc """
  Welcomes married and unmarried patrons to the Jawaii Tavern as Employee Buffy.

  ## Behavior

  - Uses gender-specific dialogue for patrons.
  - Responds to welcome and solo events with different emotions.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - DNett123
    - L0ne_w0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "jawaii_in",
        x: 25,
        y: 98,
        dir: 0,
        sprite: 724,
        name: "Employee",
        scope: :shared,
        unique_name: "Employee#jaw3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnWelcome", ctx), do: emotion(ctx, :chup)
  def on_event("OnSolo", ctx), do: emotion(ctx, :huk)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = ctx |> mes("[Employee Buffy]") |> mes("Welcome to Jawaii Tavern~")

    partner_id = getpartnerid(ctx)

    cond do
      Rathena.truthy?(partner_id) -> greet_married_patron(ctx)
      not Rathena.truthy?(partner_id) -> greet_single_patron(ctx)
      true -> ctx |> mes("I hope you will have a good time.") |> close()
    end
  end

  defp greet_married_patron(ctx) do
    ctx =
      ctx
      |> next()
      |> mes("[Employee Buffy]")
      |> mes("Oh~")
      |> mes("Look at you...")
      |> mes("You look perfect")

    ctx =
      if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
        mes(ctx, "for your wife~")
      else
        mes(ctx, "with your husband~")
      end

    ctx |> mes("Awwww, I want to") |> mes("get married soon~!") |> close()
  end

  defp greet_single_patron(ctx) do
    ctx =
      ctx
      |> next()
      |> mes("[Employee Buffy]")
      |> mes("Hmm...?")
      |> mes("You don't look like")
      |> mes("you're married, are you?")

    ctx =
      if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
        ctx
        |> next()
        |> mes("[Employee Buffy]")
        |> mes("I'm pretty good")
        |> mes("at cooking and cleaning")
        |> mes("^666666*AHEM*^000000 I've got a ^FF0000nice body^000000.")
        |> mes("So what do you think...?")
      else
        ctx
      end

    close(ctx)
  end
end
