<script lang="ts">
	// Imports
	import { resolve } from '$app/paths';
	import { BoxIcon } from 'lucide-svelte';
	import { type Component } from 'svelte';

	// Props with TypeScript types
	let {
		icon = BoxIcon,
		heading,
		description,
		actionText,
		actionHref,
		onAction
	} = $props<{
		icon?: Component;
		heading: string;
		description: string;
		actionText?: string;
		actionHref?: string;
		onAction?: () => void;
	}>();

	// Handle action button click
	function handleAction() {
		if (onAction) {
			onAction();
		}
	}

	// Determine if action should be rendered
	const hasAction = $derived(Boolean(actionText && (actionHref || onAction)));
</script>

<div
	class="flex flex-col items-center justify-center py-12 px-4 text-center"
	role="status"
	aria-label="Empty state"
>
	<!-- Icon -->
	{#if icon}
		{@const Icon = icon}
		<div class="mb-4 text-gray-400" aria-hidden="true">
			<Icon class="w-16 h-16 stroke-1" />
		</div>
	{/if}

	<!-- Heading -->
	<h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-2">
		{heading}
	</h3>

	<!-- Description -->
	<p class="text-sm text-gray-600 dark:text-gray-400 max-w-md mb-6">
		{description}
	</p>

	<!-- Action Button -->
	{#if hasAction}
		{#if actionHref}
			<a
				href={resolve(actionHref)}
				class="inline-flex items-center justify-center px-4 py-2 text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 rounded-md transition-colors"
				aria-label={actionText}
			>
				{actionText}
			</a>
		{:else if onAction}
			<button
				type="button"
				onclick={handleAction}
				class="inline-flex items-center justify-center px-4 py-2 text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 rounded-md transition-colors"
				aria-label={actionText}
			>
				{actionText}
			</button>
		{/if}
	{/if}
</div>
