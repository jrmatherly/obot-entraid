<script lang="ts">
	import { SearchIcon, X } from 'lucide-svelte';
	import { twMerge } from 'tailwind-merge';

	interface Props {
		onChange: (value: string) => void;
		class?: string;
		placeholder?: string;
		onMouseDown?: (e: MouseEvent) => void;
		onMouseUp?: (e: MouseEvent) => void;
		compact?: boolean;
		value?: string;
		showHint?: boolean;
	}

	let {
		onChange,
		class: klass,
		placeholder = 'Search Projects...',
		onMouseDown,
		onMouseUp,
		compact,
		value = '',
		showHint = false,
		...restProps
	}: Props = $props();
	let searchTimeout: ReturnType<typeof setTimeout>;
	let input = $state<HTMLInputElement | null>(null);
	let hasValue = $derived(value.length > 0);

	function search(e: Event) {
		const value = (e.target as HTMLInputElement).value;

		// Clear previous timeout
		if (searchTimeout) clearTimeout(searchTimeout);

		// Set new timeout for debounced search
		searchTimeout = setTimeout(() => {
			onChange(value);
		}, 300);
	}

	function handleKeyDown(e: KeyboardEvent) {
		if (e.key === 'Escape') {
			clear();
		}
	}

	export function clear() {
		if (input) {
			input.value = '';
		}
		onChange('');
	}
</script>

<div class="relative w-full" {...restProps}>
	<input
		bind:this={input}
		{value}
		type="text"
		{placeholder}
		class={twMerge(
			'bg-surface1 peer hover:ring-primary focus:ring-primary w-full rounded-lg px-2.5 py-3 pl-12 ring-2 ring-transparent transition-all duration-200 hover:ring-2 focus:w-full focus:ring-2 focus:outline-hidden',
			compact && 'py-2 pl-8',
			hasValue && 'pr-10',
			klass
		)}
		oninput={search}
		onkeydown={handleKeyDown}
		onmousedown={onMouseDown}
		onmouseup={onMouseUp}
	/>
	<button
		class={twMerge(
			'text-gray peer-focus:text-primary absolute top-1/2 left-4 -translate-y-1/2',
			compact && 'left-2.5'
		)}
		onclick={() => input?.focus()}
	>
		<SearchIcon class={twMerge(compact && 'size-4')} />
	</button>
	{#if hasValue}
		<button
			class={twMerge(
				'text-gray hover:text-on-surface absolute top-1/2 right-3 -translate-y-1/2 transition-colors',
				compact && 'right-2'
			)}
			onclick={clear}
			type="button"
		>
			<X class={twMerge('size-5', compact && 'size-4')} />
		</button>
		{#if showHint}
			<span
				class={twMerge(
					'text-gray absolute right-14 top-1/2 -translate-y-1/2 text-xs',
					compact && 'right-10 text-[10px]'
				)}
			>
				Esc to clear
			</span>
		{/if}
	{/if}
</div>
